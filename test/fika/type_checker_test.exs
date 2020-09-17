defmodule Fika.TypeCheckerTest do
  use ExUnit.Case
  alias Fika.{
    Env,
    TypeChecker
  }

  test "infer type of integer literals" do
    str = "123"

    {:ok, [ast], _, _, _, _} = Fika.Parser.expression(str)

    assert {:ok, "Int", _} = TypeChecker.infer_exp(Env.init(), ast)
  end

  test "infer type of arithmetic expressions" do
    str = "1 + 2"

    {:ok, [ast], _, _, _, _} = Fika.Parser.expression(str)

    assert {:ok, "Int", _} = TypeChecker.infer_exp(Env.init(), ast)
  end

  test "infer undefined variable" do
    str = "foo"

    {:ok, [ast], _, _, _, _} = Fika.Parser.expression(str)

    assert {:error, "Unknown variable: foo"} = TypeChecker.infer_exp(Env.init(), ast)
  end

  test "infer function's return type" do
    str = """
    fn foo(a: Int) do
      a
    end
    """

    {:module, _, [function]} = ast = Fika.Parser.parse_module(str, "test")

    env =
      Env.init()
      |> Env.init_module_env("test", ast)

    assert {:ok, "Int", _} = TypeChecker.infer(function, env)
  end

  test "check returns error when return type is not the inferred type" do
    str = """
    fn foo(a: Int) : Float do
      a
    end
    """

    {:module, _, [function]} = ast = Fika.Parser.parse_module(str, "test")

    env =
      Env.init()
      |> Env.init_module_env("test", ast)

    assert {:error, "Expected type: Float, got: Int"} = TypeChecker.check(function, env)
  end

  test "infer return type of another function in the module" do
    str = """
    fn foo(a: Int) : Int do
      bar(a) + 100
    end

    fn bar(a: Int) : Int do
      a + 20
    end
    """

    {:module, _, [foo, _bar]} = ast = Fika.Parser.parse_module(str, "test")

    env =
      Env.init()
      |> Env.init_module_env("test", ast)

    assert {:ok, "Int", env} = TypeChecker.infer(foo, env)

    assert Env.get_function_type(env, "test.foo(Int)") == "Int"
    assert Env.get_function_type(env, "test.bar(Int)") == "Int"
  end

  test "infer function with variable assignments which get used in function calls" do
    str = """
    fn foo(a:Int, b:Float) : Float do
      x = 123
      y = 456
      z = test2.div(test2.add(x, test2.add(y, a)), b)
    end
    """

    {:module, _, [function]} = ast = Fika.Parser.parse_module(str, "test1")

    env =
      Env.init()
      |> Env.init_module_env("test", ast)
      |> Env.add_function_type("test2.div(Float,Int)", "Float")
      |> Env.add_function_type("test2.div(Int,Float)", "Float")
      |> Env.add_function_type("test2.add(Float,Int)", "Float")
      |> Env.add_function_type("test2.add(Int,Float)", "Float")
      |> Env.add_function_type("test2.add(Int,Int)", "Int")

    assert {:ok, "Float", _} = TypeChecker.infer(function, env)
    assert {:ok, "Float", _} = TypeChecker.check(function, env)
  end

  test "string" do
    str = "\"Hello world\""

    {:ok, [ast], _, _, _, _} = Fika.Parser.expression(str)

    assert {:ok, "String", _} = TypeChecker.infer_exp(Env.init(), ast)
  end

  describe "lists" do
    test "list of integers" do
      str = "[1, 2, 3]"

      {:ok, [ast], _, _, _, _} = Fika.Parser.expression(str)

      assert {:ok, "List(Int)", _} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "list of integers and floats" do
      str = "[1, 2/3, 3]"

      {:ok, [ast], _, _, _, _} = Fika.Parser.expression(str)

      assert {:error, "Elements of list have different types. Expected: Int, got: Float"} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "list of floats inferred from fn calls" do
      str = "[1/2, 2/3]"

      {:ok, [ast], _, _, _, _} = Fika.Parser.expression(str)

      assert {:ok, "List(Float)", _} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "List of strings" do
      str = "[\"foo\", \"bar\"]"

      {:ok, [ast], _, _, _, _} = Fika.Parser.expression(str)

      assert {:ok, "List(String)", _} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "List of list of integers" do
      str = "[[1, 2], [3, 4]]"

      {:ok, [ast], _, _, _, _} = Fika.Parser.expression(str)

      assert {:ok, "List(List(Int))", _} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "empty list" do
      str = "[]"

      {:ok, [ast], _, _, _, _} = Fika.Parser.expression(str)

      assert {:ok, "List(Nothing)", _} = TypeChecker.infer_exp(Env.init(), ast)
    end
  end

  describe "record" do
    test "unnamed record" do
      str = "{foo: 123, bar: \"Baz\"}"

      {:ok, [ast], _, _, _, _} = Fika.Parser.expression(str)

      assert {:ok, "{foo:Int,bar:String}", _} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "error" do
      str = "{foo: x, bar: \"Baz\"}"

      {:ok, [ast], _, _, _, _} = Fika.Parser.expression(str)

      assert {:error, "Unknown variable: x"} = TypeChecker.infer_exp(Env.init(), ast)
    end
  end
end
