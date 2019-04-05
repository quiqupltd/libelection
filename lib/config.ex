defmodule Election.Config do
  @moduledoc """
  Helpers for getting config
  """
  def fetch_config do
    config = :libelection |> Application.get_all_env() |> Map.new()
    Enum.map(config, fn {key, _value} -> {key, EnvConfig.get(:libelection, key)} end)
  end
end
