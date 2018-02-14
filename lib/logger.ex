defmodule Election.Logger do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      require Logger

      def log(level, tag, fun) when is_function(fun), do: Logger.log(level, "#{tags(tag)} #{fun.()}")
      def log(level, tag, message), do: Logger.log(level, "#{tags(tag)} #{message}")
      defp tags(tag), do: "[libelection][#{tag}]"
    end
  end
end
