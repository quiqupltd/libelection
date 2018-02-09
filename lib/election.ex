defmodule Election do
  alias Election.Elector

  defdelegate leader, to: Elector
  defdelegate leader(pid), to: Elector
  defdelegate leader?, to: Elector
  defdelegate leader?(pid), to: Elector
end
