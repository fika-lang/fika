defmodule Fika.Compiler.CodeServerTest do
  use ExUnit.Case, async: false

  alias Fika.Compiler.CodeServer

  setup do
    CodeServer.reset()
  end

  test "when module has a dependency" do
    tmp_dir = System.tmp_dir!()
    temp_file_1 = Path.join(tmp_dir, "foo.fi")

    str = """
    use bar

    fn foo : String do
      bar.hello(:a)
    end
    """

    File.write!(temp_file_1, str)

    temp_file_2 = Path.join(tmp_dir, "bar.fi")

    str = """
    fn hello(x: :a | :b) : String do
      case x do
        :a -> "A"
        :b -> "B"
      end
    end
    """

    File.write!(temp_file_2, str)

    File.cd!(tmp_dir, fn ->
      assert {:ok,
              [
                {"foo", :ok},
                {"bar", :ok}
              ]} == CodeServer.compile_module("foo")
    end)

    File.rm!(temp_file_1)
    File.rm!(temp_file_2)
  end

  test "when module has a non existent dependency" do
    tmp_dir = System.tmp_dir!()
    temp_file_1 = Path.join(tmp_dir, "foo.fi")

    str = """
    use bar

    fn foo : String do
      bar.hello()
    end
    """

    File.write!(temp_file_1, str)

    File.cd!(tmp_dir, fn ->
      assert {:error,
              [
                {"foo", {:error, "Type check error"}},
                {"bar", {:error, "Cannot read file bar.fi: :enoent"}}
              ]} == CodeServer.compile_module("foo")
    end)

    File.rm!(temp_file_1)
  end

  test "when function does not exist in the dependency module" do
    tmp_dir = System.tmp_dir!()
    temp_file_1 = Path.join(tmp_dir, "foo.fi")

    str = """
    use bar

    fn foo : String do
      bar.hello()
    end
    """

    File.write!(temp_file_1, str)

    temp_file_2 = Path.join(tmp_dir, "bar.fi")

    str = """
    fn hello_world : String do
      "Hello world"
    end
    """

    File.write!(temp_file_2, str)

    File.cd!(tmp_dir, fn ->
      assert {:error,
              [
                {"foo", {:error, "Type check error"}},
                {"bar", :ok}
              ]} == CodeServer.compile_module("foo")
    end)

    File.rm!(temp_file_1)
    File.rm!(temp_file_2)
  end
end
