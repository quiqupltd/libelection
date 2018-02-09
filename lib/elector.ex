defmodule Election.Elector do
  @moduledoc """
  This module implements simple leader election using a provided strategy module

  ## Options

  - `strategy`: A module to use to determine candidate nodes and pick one of them as the leader
  - `first_election_in`: How much time in milliseconds before trying to elect a leader
  for the first time. Defaults in 0.
  - `polling_interval`: How often to re-elect in milliseconds. Defaults to 1 second.
  """

  use GenServer
  use Election.Logger

  @name __MODULE__
  @default_polling_interval 1_000
  @default_list_nodes {__MODULE__, :list_nodes, []}
  @default_first_election_in 0

  @doc "Starts the an Election server with the given arguments"
  @spec start_link() :: GenServer.on_start
  @spec start_link(%{name: atom()} | map()) :: GenServer.on_start
  def start_link, do: start_link(%{})
  def start_link(%{name: name} = opts) when not is_nil(name), do: GenServer.start_link(@name, opts, name: name)
  def start_link(opts), do: GenServer.start_link(@name, opts, name: @name)

  @doc false
  def init(opts) do
    {:ok, %{leader: nil, config: Map.new(opts)}, Access.get(opts, :first_election_in, @default_first_election_in)}
  end

  @doc "Triggers an election"
  @spec elect() :: :ok
  @spec elect(pid()) :: :ok
  def elect, do: elect(@name)
  def elect(pid), do: GenServer.cast(pid, :elect)

  @doc "Returns the current leader node"
  @spec leader() :: node()
  @spec leader(pid()) :: node()
  def leader, do: leader(@name)
  def leader(pid), do: GenServer.call(pid, :leader)

  @doc "Returns true only if the current node is the leader"
  @spec leader?() :: boolean()
  @spec leader?(pid()) :: boolean()
  def leader?, do: leader?(@name)
  def leader?(pid), do: node() == leader(pid)

  @doc "Returns a list of all the nodes of the cluster including the current"
  @spec list_nodes :: [node()]
  def list_nodes, do: [node() | Node.list()]

  @doc false
  def handle_cast(:elect, %{config: config} = state) do
    Process.send_after(self(), :elect, Access.get(config, :polling_interval, @default_polling_interval))

    nodes =
      case Access.get(config, :list_nodes, @default_list_nodes) do
        {m, f, a} when is_atom(m) and is_atom(f) -> apply(m, f, a)
        fun when is_function(fun) -> fun.()
        other -> log :error, :elector, ":list_nodes option is invalid, got: #{inspect other}"
      end

    {:noreply, determine_election(nodes, state)}
  end

  @doc false
  def handle_call(:leader, _from, %{leader: current_leader} = state), do: {:reply, current_leader, state}

  @doc false
  def handle_info(:elect, state), do: handle_cast(:elect, state)
  def handle_info(:timeout, state), do: handle_cast(:elect, state)
  def handle_info(_, state), do: {:noreply, state}

  defp determine_election(_nodes, %{config: %{strategy: nil}} = state) do
    log :error, :elector, ":strategy option is not set"

    state
  end

  defp determine_election([current_leader], %{leader: current_leader} = state) do
    log :debug, :elector, fn -> "No connected nodes. Leader unchanged #{inspect current_leader}" end

    state
  end

  defp determine_election([current_node], %{leader: current_leader} = state) when current_node == node() do
    log :debug, :elector, fn ->
      "No connected nodes. Electing self #{inspect current_node}, previous: #{current_leader}"
    end

    %{state | leader: current_node}
  end


  defp determine_election(nodes, %{leader: current_leader, config: %{strategy: strategy} = config} = state)
  when is_list(nodes) do
    log :debug, :elector, fn -> "Candidate nodes: #{inspect nodes}" end

    case nodes |> strategy.leader(config) do
      nil -> state
      %{node: ^current_leader, metadata: _} = elected -> reelection(elected, state)
      %{node: _elected_node, metadata: _} = elected -> new_leader(elected, state)
      _ ->
        log :error, :elector, "Strategy returned an invalid election result"
        state
    end
  end

  defp reelection(%{node: _, metadata: metadata}, %{leader: current_leader} = state) do
    log :debug, :elector, fn -> "Re-elected: #{inspect current_leader}, metadata: #{inspect metadata}" end

    state
  end

  def new_leader(%{node: elected_node, metadata: metadata}, %{leader: current_leader} = state) do
    log :debug, :elector, fn ->
      "New leader: #{elected_node}, metadata: #{inspect metadata}, previous: #{current_leader}"
    end

    %{state | leader: elected_node}
  end
end
