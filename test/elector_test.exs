defmodule Election.ElectorTest do
  use ExUnit.Case, async: true

  alias Election.Elector, as: Subject

  defmodule Election.MockStrategy do
    def leader(_nodes, _config), do: %{node: node(), metadata: %{}}
  end

  defmodule Election.MockStrategyFailed do
    def leader(_nodes, _config), do: nil
  end

  defmodule Election.MockStrategyRemoteNode do
    def leader(_nodes, _config), do: %{node: :"some@othernode", metadata: %{}}
  end

  alias Election.{MockStrategy, MockStrategyFailed, MockStrategyRemoteNode}

  @default_opts %{name: :elector, strategy: MockStrategy}

  describe "initialization" do
    test "returns a process" do
      {:ok, pid} = Subject.start_link(@default_opts)

      assert is_pid(pid)
    end

    test "initializes the leader as nil" do
      {:ok, pid} = Subject.start_link(Map.merge(@default_opts, %{name: :elector, first_election_in: 5_000}))

      assert Subject.leader(pid) == nil
    end

    test "keeps passed options as config" do
      opts = %{name: :election_test, first_election_in: 5_000, polling_interval: 2_000}
      {:ok, pid} = Subject.start_link(opts)

      assert :sys.get_state(pid).config == opts
    end
  end

  describe "elect/1 with no connected nodes" do
    test "when the :first_election_in config option is not provided the first election happens immediately" do
      {:ok, pid} = Subject.start_link(@default_opts)

      assert Subject.leader(pid) == node()
    end

    test "when the :first_election_in config option is provided, it configures the first election" do
      :erlang.trace(:new, true, [:receive])

      first_election_in = 200

      {:ok, pid} = Subject.start_link(Map.merge(@default_opts, %{first_election_in: first_election_in}))

      {election_happened_in, _} =
        :timer.tc(fn ->
          receive do
            {:trace, ^pid, :receive, :timeout} -> :ok
          after
              400 -> raise "Did not start the first election in the configured time frame"
          end
        end)

      assert_in_delta election_happened_in / 1000, first_election_in, 50
    end

    test "elects the current node as master" do
      {:ok, pid} = Subject.start_link(@default_opts)

      Subject.elect(pid)

      assert Subject.leader(pid) == node()
    end

    test "when the current node is master, does not change the state" do
      {:ok, pid} = Subject.start_link(@default_opts)

      Subject.elect(pid)

      assert Subject.leader(pid) == node()

      Subject.elect(pid)

      assert Subject.leader(pid) == node()
    end
  end

  describe "elect/1 with connected nodes" do
    test "when the current node is determined as the leader by the strategy, it updates the leader" do
      {:ok, pid} = Subject.start_link(Map.merge(@default_opts, %{strategy: MockStrategyFailed}))

      assert Subject.leader(pid) == node()
    end

    test "when the strategy fails to elect, it does not update the strategy" do
      {:ok, pid} = Subject.start_link(Map.merge(@default_opts, %{strategy: MockStrategyFailed}))

      leader = :"somenode@somehost"
      :sys.replace_state(pid, fn state -> %{state | leader: leader} end)

      Subject.elect(pid)

      refute Subject.leader(pid) == leader
    end
  end

  describe "leader/1 when the current node is leader" do
    test "returns the current node" do
      {:ok, pid} = Subject.start_link(@default_opts)

      assert Subject.leader(pid) == node()
    end
  end

  describe "leader/1 when the current node is not leader" do
    test "does not return the current node" do
      remote_node = :"somenode@somehost"
      opts = Map.merge(@default_opts, %{strategy: MockStrategyRemoteNode, list_nodes: fn -> [node(), remote_node] end})

      {:ok, pid} = Subject.start_link(opts)

      refute Subject.leader(pid) == node()
    end
  end

  describe "leader?/1 when the current node is leader" do
    test "returns true" do
      {:ok, pid} = Subject.start_link(@default_opts)

      assert Subject.leader?(pid) == true
    end
  end

  describe "leader?/1 when the current node is not leader" do
    test "returns false" do
      remote_node = :"somenode@somehost"
      opts = Map.merge(@default_opts, %{strategy: MockStrategyRemoteNode, list_nodes: fn -> [node(), remote_node] end})
      {:ok, pid} = Subject.start_link(opts)

      assert Subject.leader?(pid) == false
    end
  end
end
