defmodule Fika.Compiler.ModuleCompilerTest do
  use ExUnit.Case, async: false

  alias Fika.Compiler.{
    ModuleCompiler
  }

  test "given a file with fika code, returns the compiled binary" do
    module = Path.join(System.tmp_dir!(), "foo") |> String.to_atom()
    temp_file = "#{module}.fi"

    str = """
    fn foo : String do
      "Hello world"
    end
    """

    File.write!(temp_file, str)

    assert {:ok, ^module, ^temp_file, _binary} = ModuleCompiler.compile(module)

    File.rm!(temp_file)
  end

  test "returns error when file doesn't exist" do
    module = Path.join(System.tmp_dir!(), "foo") |> String.to_atom()

    assert {:error, "Cannot read file #{module}.fi: :enoent"} == ModuleCompiler.compile(module)
  end

  test "returns error when file cannot be parsed" do
    module = Path.join(System.tmp_dir!(), "foo") |> String.to_atom()

    temp_file = "#{module}.fi"

    str = """
    function foo = "hello world"
    """

    File.write!(temp_file, str)

    assert {:error, "Parse error"} == ModuleCompiler.compile(module)

    File.rm!(temp_file)
  end

  test "returns error when type check fails" do
    module = Path.join(System.tmp_dir!(), "foo") |> String.to_atom()

    temp_file = "#{module}.fi"

    str = """
    fn foo : Int do
      "Hello world"
    end
    """

    File.write!(temp_file, str)

    assert {:error, "Type check error"} == ModuleCompiler.compile(module)

    File.rm!(temp_file)
  end
end
