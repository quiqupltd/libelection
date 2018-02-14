defmodule Election do
  @moduledoc """
  The core context of the library.

  Usage:

  ```elixir
  if Election.leader? do
    # Code only the leader should execute
  else
    #
  end
  ```

  If a node is not connected to any other nodes, considers himself as leader.
  """

  alias Election.Elector

  defdelegate leader, to: Elector
  defdelegate leader(pid), to: Elector
  defdelegate leader?, to: Elector
  defdelegate leader?(pid), to: Elector
end
