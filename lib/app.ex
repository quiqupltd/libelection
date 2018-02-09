defmodule Election.App do
  @doc false
  use Application

  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    Supervisor.start_link(child_specs(), [strategy: :one_for_one, name: Election.Supervisor])
  end

  defp child_specs, do: [worker(Election.Elector, [config()])]

  defp config, do: Application.get_all_env(:libelection)
end
