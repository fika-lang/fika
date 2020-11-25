defmodule Mix.Tasks.Compile.Fika do
  use Mix.Task.Compiler

  alias Fika.Code

  def run(_args) do
    {:ok, _} = Application.ensure_all_started(:fika)

    Code.compile_to_path("fika/kernel", Mix.Project.compile_path())

    :ok
  end
end
