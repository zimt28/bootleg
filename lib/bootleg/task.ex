defmodule Bootleg.Task do
  @moduledoc "Extends `Mix.Task` to provide Bootleg specific bootstrapping."
  alias Bootleg.{Config, Tasks}

  defmacro __using__(task) do
    quote do
      use Mix.Task

      @spec run(OptionParser.argv) :: :ok
      if is_atom(unquote(task)) && unquote(task) do
        def run(_args) do
          use Config

          Tasks.load_tasks
          invoke unquote(task)
        end
      else
        def run(_args) do
          Tasks.load_tasks
        end
      end

      defoverridable [run: 1]
    end
  end
end