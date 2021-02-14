defmodule Mix.Tasks.Compile.Fika do
  use Mix.Task.Compiler

  alias Fika.Code
  require Logger

  def run(_args) do
    level = Logger.level()
    Logger.configure(level: :warn)
    {:ok, _} = Application.ensure_all_started(:fika)

    dest = Mix.Project.compile_path()

    "fika/**/*.fi"
    |> Path.wildcard()
    |> Enum.each(&compile_to_path(&1, dest))

    Application.stop(:fika)
    Logger.configure(level: level)

    :ok
  end

  defp compile_to_path(file, dest) do
    module = String.replace_suffix(file, ".fi", "")
    Logger.info("Compiling stdlib module: #{module}")
    Code.compile_to_path(module, dest)
  end
end
