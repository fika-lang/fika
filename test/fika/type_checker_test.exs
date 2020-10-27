defmodule Fika.TypeCheckerTest do
  use ExUnit.Case

  alias Fika.{
    Env,
    TypeChecker
  }

  alias Fika.Types.FunctionRef

  test "infer type of integer literals" do
    str = "123"

    ast = TestParser.expression!(str)

    assert {:ok, :Int, _} = TypeChecker.infer_exp(Env.init(), ast)
  end

  test "infer type of atom expressions" do
    str = ":a"

    {:atom, {1, 0, 2}, :a} = ast = TestParser.expression!(str)

    assert {:ok, %Fika.Types.Atom{value: :a}, _} = TypeChecker.infer_exp(Env.init(), ast)
  end

  test "infer type for list of atom expressions" do
    str = "[:a, :a]"

    ast = TestParser.expression!(str)

    assert {:ok, %Fika.Types.List{type: %Fika.Types.Atom{value: :a}}, _} =
             TypeChecker.infer_exp(Env.init(), ast)
  end

  test "infer type of arithmetic expressions" do
    str = "-1 + 2"

    ast = TestParser.expression!(str)

    assert {:ok, :Int, _} = TypeChecker.infer_exp(Env.init(), ast)
  end

  describe "logical operators" do
    test "infer type of logical expressions" do
      # and
      str = "true & false"
      ast = TestParser.expression!(str)
      assert {:ok, :Bool, _} = TypeChecker.infer_exp(Env.init(), ast)

      # or
      str = "true | false"
      ast = TestParser.expression!(str)
      assert {:ok, :Bool, _} = TypeChecker.infer_exp(Env.init(), ast)

      # negation
      str = "!true"
      ast = TestParser.expression!(str)
      assert {:ok, :Bool, _} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "infer type of logical expressions when using atoms" do
      str = "true & :false"
      ast = TestParser.expression!(str)
      assert {:ok, :Bool, _} = TypeChecker.infer_exp(Env.init(), ast)
    end
  end

  test "infer undefined variable" do
    str = "foo"

    ast = TestParser.expression!(str)

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

  test "checks tuple return type for function" do
    str = """
    fn foo : {Float} do
      {2}
    end
    """

    {:module, _, [function]} = ast = Fika.Parser.parse_module(str, "test")

    env =
      Env.init()
      |> Env.init_module_env("test", ast)

    assert {:error, "Expected type: {Float}, got: {Int}"} = TypeChecker.check(function, env)
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

    assert Env.get_function_type(env, "test.foo(Int)") == :Int
    assert Env.get_function_type(env, "test.bar(Int)") == :Int
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

    ast = TestParser.expression!(str)

    assert {:ok, :String, _} = TypeChecker.infer_exp(Env.init(), ast)
  end

  describe "lists" do
    test "list of integers" do
      str = "[1, 2, 3]"

      ast = TestParser.expression!(str)

      assert {:ok, %Fika.Types.List{type: :Int}, _} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "list of integers and floats" do
      str = "[1, 2/3, 3]"

      ast = TestParser.expression!(str)

      assert {:error, "Elements of list have different types. Expected: Int, got: Float"} =
               TypeChecker.infer_exp(Env.init(), ast)
    end

    test "list of floats inferred from fn calls" do
      str = "[1/2, 2/3]"

      ast = TestParser.expression!(str)

      assert {:ok, %Fika.Types.List{type: :Float}, _} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "List of strings" do
      str = "[\"foo\", \"bar\"]"

      ast = TestParser.expression!(str)

      assert {:ok, %Fika.Types.List{type: :String}, _} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "List of list of integers" do
      str = "[[1, 2], [3, 4]]"

      ast = TestParser.expression!(str)

      assert {:ok, %Fika.Types.List{type: %Fika.Types.List{type: :Int}}, _} =
               TypeChecker.infer_exp(Env.init(), ast)
    end

    test "empty list" do
      str = "[]"

      ast = TestParser.expression!(str)

      assert {:ok, %Fika.Types.List{type: :Nothing}, _} = TypeChecker.infer_exp(Env.init(), ast)
    end
  end

  describe "tuples" do
    test "tuple of integers" do
      str = "{1, 2, 3}"

      ast = TestParser.expression!(str)

      assert {:ok, %Fika.Types.Tuple{elements: %Fika.Types.ArgList{value: [:Int, :Int, :Int]}},
              _env} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "tuple of integers and floats" do
      str = "{1, 2/3, 3}"

      ast = TestParser.expression!(str)

      assert {:ok, %Fika.Types.Tuple{elements: %Fika.Types.ArgList{value: [:Int, :Float, :Int]}},
              _env} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "tuple of floats inferred from fn calls" do
      str = "{1/2, 2/3}"

      ast = TestParser.expression!(str)

      assert {:ok, %Fika.Types.Tuple{elements: %Fika.Types.ArgList{value: [:Float, :Float]}},
              _env} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "tuple of strings" do
      str = ~s({"foo", "bar"})

      ast = TestParser.expression!(str)

      assert {:ok, %Fika.Types.Tuple{elements: %Fika.Types.ArgList{value: [:String, :String]}},
              _env} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "tuple of tuple of mixed types" do
      str = ~s({{1, 2/5}, {"3", true}})

      ast = TestParser.expression!(str)

      assert {:ok,
              %Fika.Types.Tuple{
                elements: %Fika.Types.ArgList{
                  value: [
                    %Fika.Types.Tuple{elements: %Fika.Types.ArgList{value: [:Bool, :String]}},
                    %Fika.Types.Tuple{elements: %Fika.Types.ArgList{value: [:Float, :Int]}}
                  ]
                }
              }, _env} = TypeChecker.infer_exp(Env.init(), ast)
    end
  end

  describe "record" do
    test "unnamed record" do
      str = "{foo: 123, bar: \"Baz\"}"

      ast = TestParser.expression!(str)

      assert {:ok, %Fika.Types.Record{fields: [bar: :String, foo: :Int]}, _} =
               TypeChecker.infer_exp(Env.init(), ast)
    end

    test "error" do
      str = "{foo: x, bar: \"Baz\"}"

      ast = TestParser.expression!(str)

      assert {:error, "Unknown variable: x"} = TypeChecker.infer_exp(Env.init(), ast)
    end
  end

  describe "function reference" do
    test "with args" do
      str = "&bar.sum(Int, Int)"
      ast = TestParser.expression!(str)

      env =
        Env.init()
        |> Env.init_module_env("test", ast)
        |> Env.add_function_type("bar.sum(Int,Int)", "Int")

      assert {:ok,
              %FunctionRef{
                arg_types: %Fika.Types.ArgList{value: ["Int", "Int"]},
                return_type: "Int"
              }, _} = TypeChecker.infer_exp(env, ast)
    end

    test "without args" do
      str = "&bar.sum"
      ast = TestParser.expression!(str)

      env =
        Env.init()
        |> Env.init_module_env("test", ast)
        |> Env.add_function_type("bar.sum()", "Int")

      assert {:ok, %FunctionRef{arg_types: %Fika.Types.ArgList{}, return_type: "Int"}, _} =
               TypeChecker.infer_exp(env, ast)
    end
  end

  describe "boolean" do
    test "true" do
      str = "true"
      ast = TestParser.expression!(str)

      assert {:ok, :Bool, _} = TypeChecker.infer_exp(Env.init(), ast)
    end

    test "false" do
      str = "false"
      ast = TestParser.expression!(str)

      assert {:ok, :Bool, _} = TypeChecker.infer_exp(Env.init(), ast)
    end
  end

  describe "if-else expression" do
    test "error when condition expression has non-boolean type" do
      str = """
      if "true" do
        "foo"
      else
        "bar"
      end
      """

      ast = TestParser.expression!(str)
      env = Env.init_module_env(Env.init(), "test", ast)

      assert {
               :error,
               "Wrong type for if condition. Expected: Bool, Got: String"
             } = TypeChecker.infer_exp(env, ast)
    end

    test "completes when if and else blocks have same return type" do
      str = """
      if true do
        "done"
      else
        "500"
      end
      """

      ast = TestParser.expression!(str)
      env = Env.init_module_env(Env.init(), "test", ast)

      assert {:ok, :String, _env} = TypeChecker.infer_exp(env, ast)
    end

    test "error when if and else blocks have different return types" do
      str = """
      if false do
        "done"
      else
        500
      end
      """

      ast = TestParser.expression!(str)
      env = Env.init_module_env(Env.init(), "test", ast)

      assert {
               :error,
               "Expected if and else blocks to have same return type. Got String and Int"
             } = TypeChecker.infer_exp(env, ast)
    end

    test "with multiple expressions in blocks" do
      str = """
      if true do
        a = "done"
        a
      else
        "500"
      end
      """

      ast = TestParser.expression!(str)
      env = Env.init_module_env(Env.init(), "test", ast)

      assert {:ok, :String, _env} = TypeChecker.infer_exp(env, ast)
    end
  end

  describe "function calls using reference" do
    test "valid reference" do
      str = """
      fn foo do
        x = &test2.bar(String, Int)
        x.("hello", 123)
      end
      """

      {:module, _, [function]} = ast = Fika.Parser.parse_module(str, "test1")

      env =
        Env.init()
        |> Env.init_module_env("test", ast)
        |> Env.add_function_type("test2.bar(String,Int)", :Bool)

      assert {:ok, "Bool", _} = TypeChecker.infer(function, env)
    end

    test "identifier is not a reference" do
      str = """
      fn foo do
        x = 123
        x.()
      end
      """

      {:module, _, [function]} = ast = Fika.Parser.parse_module(str, "test1")

      env =
        Env.init()
        |> Env.init_module_env("test", ast)

      assert {:error, "Expected a function reference, but got type: Int"} =
               TypeChecker.infer(function, env)
    end

    test "function ref when given wrong types" do
      str = """
      fn foo do
        x = &test2.bar(String, Int)
        x.(123)
      end
      """

      {:module, _, [function]} = ast = Fika.Parser.parse_module(str, "test1")

      env =
        Env.init()
        |> Env.init_module_env("test", ast)
        |> Env.add_function_type("test2.bar(String,Int)", :Bool)

      error =
        "Expected function reference to be called with arguments (String, Int), but it was called with arguments (Int)"

      assert {:error, ^error} = TypeChecker.infer(function, env)
    end
  end
end
