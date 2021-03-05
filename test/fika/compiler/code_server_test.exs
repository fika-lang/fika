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

  describe "set_function_dependency/2" do
    setup do
      CodeServer.reset()

      :ok
    end

    test "should not change state if any of the args is nil" do
      state = CodeServer.get_dependency_graph()

      CodeServer.set_function_dependency(nil, 1)
      CodeServer.set_function_dependency(1, nil)

      assert state == CodeServer.get_dependency_graph()
    end

    test "should update the state in an idempotent manner" do
      assert :ok == CodeServer.set_function_dependency("a", "b")
      graph = CodeServer.get_dependency_graph()

      assert :ok == CodeServer.set_function_dependency("a", "b")
      assert graph == CodeServer.get_dependency_graph()

      assert %{edges: [{"a", "b"}], vertices: ["a", "b"]} == graph
    end

    test "should warn about direct dependency cycles" do
      assert :ok == CodeServer.set_function_dependency("a", "b")

      assert {:error, :cycle_encountered} == CodeServer.set_function_dependency("b", "a")
    end

    test "should warn about indirect dependency cycles" do
      assert :ok == CodeServer.set_function_dependency("a", "b")
      assert :ok == CodeServer.set_function_dependency("b", "c")
      assert {:error, :cycle_encountered} == CodeServer.set_function_dependency("c", "a")

      nodes = ["a", "b", "c"]

      for x <- nodes, y <- nodes do
        assert {:error, :cycle_encountered} == CodeServer.set_function_dependency(x, y)
      end
    end

    test "should correctly handle acyclic graphs" do
      assert :ok == CodeServer.set_function_dependency("a", "x")
      assert :ok == CodeServer.set_function_dependency("b", "c")
      assert :ok == CodeServer.set_function_dependency("c", "a")
    end
  end
end
