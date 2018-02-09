defmodule Election.Strategy.Rancher do
  @moduledoc """
  This leader election strategy leverages the Rancher Metadata API
  Docs: http://rancher.com/docs/rancher/latest/en/rancher-services/metadata-service/

  When a container is spawned from Rancher it's assigned a Integer as "create_index" which
  is guaranteed to be higher than any existing container for the service.
  This module sets as leader the node of the container with the lowest "create_index" attribute.

  ## Options
  - `rancher_node_basename`: The shared name of the Rancher nodes. For a `example@127.0.0.1`, it would be `example`.
  """

  use Election.Logger

  @rancher_api_base_url "http://rancher-metadata"
  @service_path "latest/self/service"

  @doc "Returns the leader node of the cluster"
  @spec leader(node(), %{}) :: %{node: node(), metadata: map()} | nil
  def leader(connected_nodes, config) do
    case discover_nodes(config) do
      nodes when is_list(nodes) ->
        %{node: leader_node, create_index: create_index} = nodes
          |> Enum.filter(&(&1.node in connected_nodes))
          |> Enum.min_by(&(&1.create_index))

        %{node: leader_node, metadata: %{create_index: create_index}}
      {:error, reason} ->
        log :error, :rancher, "Failed to fetch nodes with error: #{inspect reason}"

        nil
      _ ->
        log :error, :rancher, "Unexpected response from Rancher API"

        nil
    end
  end

  defp discover_nodes(config) do
    headers = [{'accept', 'application/json'}]
    app_name = Access.get(config, :rancher_node_basename)

    case :httpc.request(:get, {'#{@rancher_api_base_url}/#{@service_path}', headers}, [], []) do
      {:ok, {{_version, 200, _status}, _headers, body}} ->
        parse_response(app_name, Poison.decode!(body))
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_response(app_name, resp) do
    case resp do
      %{"containers" => containers} ->
        containers |> Enum.map(fn %{"create_index" => create_index, "ips" => [ip | _]} ->
          %{create_index: create_index, node: :"#{app_name}@#{ip}"}
        end)
      _ -> []
    end
  end
end
