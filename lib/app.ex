defmodule Election.App do
  @moduledoc false
  use Application

  import Supervisor.Spec, warn: false

  alias Election.Config

  def start(_type, _args) do
    Supervisor.start_link(child_specs(), strategy: :one_for_one, name: Election.Supervisor)
  end

  defp child_specs, do: [worker(Election.Elector, [Config.fetch_config()])]
end
