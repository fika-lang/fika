defmodule Fika.Compiler.CodeServerTest do
  use ExUnit.Case, async: true

  alias Fika.Compiler.CodeServer

  test "when module has a dependency" do
    module = Path.join(System.tmp_dir!(), "foo") |> String.to_atom()
    dep_module = Path.join(System.tmp_dir!(), "bar") |> String.to_atom()

    temp_file_1 = "#{module}.fi"

    str = """
    use #{dep_module}

    fn foo : String do
      bar.hello()
    end
    """

    File.write!(temp_file_1, str)

    temp_file_2 = "#{dep_module}.fi"

    str = """
    fn hello : String do
      "Hello world"
    end
    """

    File.write!(temp_file_2, str)

    assert {:ok,
            [
              ok: :"/var/folders/bb/vzln2mls1b53x4bhz4xfdyrm0000gn/T/foo",
              ok: :"/var/folders/bb/vzln2mls1b53x4bhz4xfdyrm0000gn/T/bar"
            ]} == CodeServer.compile_module(module)

    File.rm!(temp_file_1)
    File.rm!(temp_file_2)
  end

  test "when module has a non existent dependency" do
    module = Path.join(System.tmp_dir!(), "foo") |> String.to_atom()
    dep_module = Path.join(System.tmp_dir!(), "bar") |> String.to_atom()

    temp_file_1 = "#{module}.fi"

    str = """
    use #{dep_module}

    fn foo : String do
      bar.hello()
    end
    """

    File.write!(temp_file_1, str)

    assert {:error,
            [
              error: :"/var/folders/bb/vzln2mls1b53x4bhz4xfdyrm0000gn/T/foo",
              error: :"/var/folders/bb/vzln2mls1b53x4bhz4xfdyrm0000gn/T/bar"
            ]} == CodeServer.compile_module(module)

    File.rm!(temp_file_1)
  end
end
