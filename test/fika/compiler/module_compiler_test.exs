defmodule Fika.Compiler.ModuleCompilerTest do
  use ExUnit.Case, async: false

  alias Fika.Compiler.{
    ModuleCompiler
  }

  test "given a file with fika code, returns the compiled binary" do
    tmp_dir = System.tmp_dir!()
    temp_file = Path.join(tmp_dir, "foo.fi")

    str = """
    fn foo : String do
      "Hello world"
    end
    """

    File.write!(temp_file, str)

    File.cd!(tmp_dir, fn ->
      assert {:ok, "foo", "foo.fi", _binary} = ModuleCompiler.compile("foo")
    end)

    File.rm!(temp_file)
  end

  test "can compile a file with many functions" do
    tmp_dir = System.tmp_dir!()
    temp_file = Path.join(tmp_dir, "foo.fi")

    # Show that we're not limited to the number of online schedulers
    n = System.schedulers_online() * 2

    str =
      1..n
      |> Enum.map(fn number ->
        """
        fn foo_#{number} : String do
          "Hello world"
        end
        """
      end)
      |> Enum.join("\n")

    File.write!(temp_file, str)

    File.cd!(tmp_dir, fn ->
      assert {:ok, "foo", "foo.fi", _binary} = ModuleCompiler.compile("foo")
    end)

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

  test "does not hang when there is local recursion with both direct and indirect cycles" do
    module = Path.join(System.tmp_dir!(), "foo") |> String.to_atom()

    temp_file = "#{module}.fi"

    str = """
    fn f : Loop(nil) do
      g()
    end
    fn g : Loop(nil) do
      h()
    end
    fn h : Loop(nil) do
      f()
    end
    fn a : Loop(nil) do
      c()
      b()
    end
    fn b : Loop(nil) do
      c()
      a()
    end
    fn c : Int do
      1 + 1
    end
    """

    File.write!(temp_file, str)

    assert {:error, "Type check error"} == ModuleCompiler.compile(module)

    File.rm!(temp_file)
  end

  test "does not hang when there is intermodule recursion" do
    foo_module = Path.join(System.tmp_dir!(), "foo") |> String.to_atom()
    foo_temp_file = "#{foo_module}.fi"

    bar_module = Path.join(System.tmp_dir!(), "bar") |> String.to_atom()
    bar_temp_file = "#{bar_module}.fi"

    foo_str = """
    use bar

    fn f : Loop(nil) do
      bar.g()
    end
    """

    bar_str = """
    use foo

    fn g : Loop(nil) do
      foo.f()
    end
    """

    File.write!(foo_temp_file, foo_str)
    File.write!(bar_temp_file, bar_str)

    File.cd!(System.tmp_dir!(), fn ->
      assert {:ok, _, _, _} = ModuleCompiler.compile("foo")
    end)

    File.rm!(foo_temp_file)
    File.rm!(bar_temp_file)
  end

  test "infer return type when the recursion is not at the top level" do
    tmp_dir = System.tmp_dir!()
    module = Path.join(tmp_dir, "foo") |> String.to_atom()

    temp_file = "#{module}.fi"

    str = """
    fn factorial(x: Int) : Int do
      do_factorial(x, 0)
    end
    fn do_factorial(x: Int, acc: Int) : Loop(Int) do
      if x <= 1 do
        acc
      else
        do_factorial(x - 1, acc * x)
      end
    end
    fn top_level(x: Int) : Int do
      second_level_a(x)
    end
    fn second_level_a(x: Int) : Loop(Int) do
      if x > 1 do
        second_level_b(x - 1)
      else
        1
      end
    end
    fn second_level_b(x: Int) : Loop(Int) do
      second_level_a(x - 1)
    end
    """

    File.write!(temp_file, str)

    File.cd!(tmp_dir, fn ->
      assert {:ok, "foo", "foo.fi", _binary} = ModuleCompiler.compile("foo")
    end)

    File.rm!(temp_file)
  end
end
