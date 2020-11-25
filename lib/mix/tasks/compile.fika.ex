defmodule Mix.Tasks.Compile.Fika do
  use Mix.Task.Compiler

  alias Fika.Code
  require Logger

  def run(_args) do
    level = Logger.level()
    Logger.configure(level: :warn)
    {:ok, _} = Application.ensure_all_started(:fika)

    dest = Mix.Project.compile_path()
    default_modules = ["fika/io"]

    Enum.each(default_modules, fn module ->
      Logger.info("Compiling #{module}")
      Code.compile_to_path(module, dest)
    end)

    Application.stop(:fika)
    Logger.configure(level: level)

    :ok
  end
end
