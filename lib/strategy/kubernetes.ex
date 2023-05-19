defmodule Election.Strategy.Kubernetes do
  @moduledoc """
  This leader election strategy leverages the Kubernetes API

  API Docs: https://kubernetes.io/docs/concepts/overview/kubernetes-api/

  The connected node with the least `resourceVersion` is elected as leader.

  ## Options
  - `kubernetes_node_basename`: The shared name of the Kubernetes nodes. For a `example@127.0.0.1`, it would be `example`
  - `kubernetes_selector`: The label selector (see: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/) to
  apply for node discovery
  """

  use Election.Logger

  @kubernetes_api_base_url "https://kubernetes.default.svc.cluster.local"
  @service_account_path "/var/run/secrets/kubernetes.io/serviceaccount"

  @doc "Returns the leader node of the cluster"
  @spec leader([node()], %{}) :: %{node: node(), metadata: map()} | nil
  def leader(connected_nodes, config) do
    case discover_nodes(config) do
      [] ->
        log(:error, :kubernetes, "No connected nodes")

        nil

      [_ | _] = nodes ->
        with %{node: leader_node, create_index: create_index} <-
               nodes
               |> Enum.filter(&(&1.node in connected_nodes))
               |> oldest_node do
          %{node: leader_node, metadata: %{create_index: create_index}}
        end

      {:error, reason} ->
        log(:error, :kubernetes, "Failed to fetch nodes with error: #{inspect(reason)}")

        nil

      _ ->
        log(:error, :kubernetes, "Unexpected response from Kubernetes API")

        nil
    end
  end

  defp discover_nodes(config) do
    with %{app_name: app_name, selector: selector}
         when not is_nil(app_name) and not is_nil(selector) <- %{
           app_name: Access.get(config, :kubernetes_node_basename),
           selector: Access.get(config, :kubernetes_selector)
         },
         endpoints_path <- 'api/v1/namespaces/#{namespace()}/endpoints?labelSelector=#{selector}',
         url <- '#{base_url(config)}/#{endpoints_path}',
         {:response, {:ok, body}} <- {:response, api_request(url)} do
      parse_response(app_name, Poison.decode!(body))
    else
      %{app_name: app_name, selector: selector} when is_nil(app_name) or is_nil(selector) ->
        log(:warn, :kubernetes, "configuration value is nil, config: #{inspect(config)}")
        {:error, :invalud_configuration}

      {:response,
       {:error, %{message: :invalid_response_status, code: code, status: status, body: body}}} ->
        log(:warn, :kubernetes, "cannot query kubernetes (#{code} #{status}): #{inspect(body)}")

      {:response, {:error, %{message: :unauthorized, body: body}}} ->
        log(:warn, :kubernetes, "cannot query kubernetes (unauthorized): #{inspect(body)}")
        {:error, :unauthorized}

      {:response, other} ->
        {:error, :invalid_response}
    end
  end

  defp parse_response(app_name, resp) do
    case resp do
      %{"items" => []} ->
        []

      %{"items" => items} ->
        Enum.reduce(items, [], fn
          %{"subsets" => []}, acc ->
            acc

          %{"subsets" => subsets}, acc ->
            addrs =
              Enum.flat_map(subsets, fn
                %{"addresses" => addresses} ->
                  # credo:disable-for-next-line Credo.Check.Refactor.Nesting
                  Enum.map(addresses, fn %{"ip" => ip, "targetRef" => targetRef} ->
                    %{create_index: resource_version(targetRef), node: :"#{app_name}@#{ip}"}
                  end)

                _ ->
                  []
              end)

            acc ++ addrs

          _, acc ->
            acc
        end)

      _ ->
        []
    end
  end

  defp resource_version(%{"resourceVersion" => version}), do: String.to_integer(version)
  defp resource_version(_), do: 1

  @spec token() :: String.t()
  defp token, do: service_file("token")

  @spec namespace() :: String.t()
  defp namespace, do: service_file("namespace")

  @spec service_file(String.t()) :: String.t()
  defp service_file(filename) do
    path = Path.join(@service_account_path, filename)

    case File.exists?(path) do
      true -> path |> File.read!() |> String.trim()
      false -> ""
    end
  end

  defp api_request(url) do
    headers = [{'authorization', 'Bearer #{token()}'}]
    http_options = [ssl: [verify: :verify_none]]

    case :httpc.request(:get, {url, headers}, http_options, []) do
      {:ok, {{_version, 200, _status}, _headers, body}} ->
        {:ok, body}

      {:ok, {{_version, 403, _status}, _headers, body}} ->
        {:error, %{message: :unauthorized, body: Poison.decode!(body)}}

      {:ok, {{_version, code, status}, _headers, body}} ->
        {:error, %{message: :invalid_response_status, code: code, status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp oldest_node([]), do: nil
  defp oldest_node([_ | _] = nodes), do: nodes |> Enum.min_by(& &1.create_index)

  defp base_url(%{kubernetes_api_base_url: url}), do: url
  defp base_url(_), do: @kubernetes_api_base_url
end
