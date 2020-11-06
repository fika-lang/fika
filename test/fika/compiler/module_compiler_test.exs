defmodule Fika.Compiler.ModuleCompilerTest do
  use ExUnit.Case, async: true

  alias Fika.Compiler.{
    ModuleCompiler
  }

  test "given a file with fika code, returns the compiled binary" do
    module = Path.join(System.tmp_dir!(), "temp") |> String.to_atom()
    temp_file = "#{module}.fi"

    str = """
    fn foo : String do
      "Hello world"
    end
    """

    File.write!(temp_file, str)

    {:ok, ^module, ^temp_file, _binary} = ModuleCompiler.compile(module)

    File.rm!(temp_file)
  end
end
