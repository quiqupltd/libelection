defmodule Election.Logger do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      require Logger

      def log(level, tag, fun) when is_function(fun), do: maybe_log(level, "#{tags(tag)} #{fun.()}")
      def log(level, tag, message), do: maybe_log(level, "#{tags(tag)} #{message}")
      defp tags(tag), do: "[libelection][#{tag}]"

      defp maybe_log(level, message) do
        case Logger.compare_levels(log_level(), level) do
          :gt -> nil
          _ -> Logger.log(level, message)
        end
      end

      defp log_level do
        case Application.get_env(:libelection, :logger) do
          %{level: level} -> level
          _ -> :debug
        end
      end
    end
  end
end
