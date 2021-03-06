defmodule Fika.Compiler.TypeCheckerTest do
  use ExUnit.Case, async: true

  alias Fika.Compiler.{
    TypeChecker,
    Parser,
    CodeServer,
    FunctionSignature
  }

  alias Fika.Compiler.TypeChecker.Types, as: T

  setup do
    CodeServer.reset()
  end

  test "infer type of integer literals" do
    str = "123"

    ast = TestParser.expression!(str)

    assert {:ok, :Int, _} = TypeChecker.infer_exp(%{}, ast)
  end

  test "infer type of atom expressions" do
    str = ":a"

    {:atom, {1, 0, 2}, :a} = ast = TestParser.expression!(str)

    assert {:ok, :a, _} = TypeChecker.infer_exp(%{}, ast)
  end

  test "infer type for list of atom expressions" do
    str = "[:a, :a]"

    ast = TestParser.expression!(str)

    assert {:ok, %T.List{type: :a}, _} = TypeChecker.infer_exp(%{}, ast)
  end

  test "infer type of arithmetic expressions" do
    str = "-1 + 2"

    ast = TestParser.expression!(str)

    assert {:ok, :Int, _} = TypeChecker.infer_exp(%{}, ast)
  end

  describe "logical operators" do
    test "infer type of logical expressions" do
      # and
      str = "true & false"
      ast = TestParser.expression!(str)
      assert {:ok, :Bool, _} = TypeChecker.infer_exp(%{}, ast)

      # or
      str = "true | false"
      ast = TestParser.expression!(str)
      assert {:ok, :Bool, _} = TypeChecker.infer_exp(%{}, ast)

      # negation
      str = "!true"
      ast = TestParser.expression!(str)
      assert {:ok, :Bool, _} = TypeChecker.infer_exp(%{}, ast)
    end

    test "infer type of logical expressions when using atoms" do
      str = "true & :false"
      ast = TestParser.expression!(str)
      assert {:ok, :Bool, _} = TypeChecker.infer_exp(%{}, ast)
    end
  end

  test "infer undefined variable" do
    str = "foo"

    ast = TestParser.expression!(str)

    assert {:error, "Unknown variable: foo"} = TypeChecker.infer_exp(%{}, ast)
  end

  test "infer ext function's return type" do
    str = """
    ext foo(a: Int) : String = {"Test", "foo", [a]}

    fn bar(x: Int) do
      foo(x)
    end
    """

    {:ok, ast} = Parser.parse_module(str)
    env = TypeChecker.init_env(ast)

    [_foo, bar] = ast[:function_defs]

    assert {:ok, :String} = TypeChecker.infer(bar, env)
  end

  test "infer function's return type" do
    str = """
    fn foo(a: Int) do
      a
    end
    """

    {:ok, ast} = Parser.parse_module(str)

    [function] = ast[:function_defs]

    assert {:ok, :Int} = TypeChecker.infer(function, %{})
  end

  test "check returns error when return type is not the inferred type" do
    str = """
    fn foo(a: Int) : Float do
      a
    end
    """

    {:ok, ast} = Parser.parse_module(str)

    [function] = ast[:function_defs]

    assert {:error, "Expected type: Float, got: Int"} = TypeChecker.check(function, %{})
  end

  test "checks tuple return type for function" do
    str = """
    fn foo : {Float} do
      {2}
    end
    """

    {:ok, ast} = Parser.parse_module(str)

    [function] = ast[:function_defs]

    assert {:error, "Expected type: {Float}, got: {Int}"} = TypeChecker.check(function, %{})
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

    {:ok, ast} = Parser.parse_module(str)
    [foo, _bar] = ast[:function_defs]

    env = TypeChecker.init_env(ast)

    assert {:ok, :Int} = TypeChecker.infer(foo, env)
  end

  test "infer calls with multiple args" do
    str = """
    fn foo(a: Int, b: String) : Int do
      a
    end

    fn bar : Int do
      foo(5, "a")
    end
    """

    {:ok, ast} = Parser.parse_module(str)
    [_foo, bar] = ast[:function_defs]

    env = TypeChecker.init_env(ast)

    assert {:ok, :Int} = TypeChecker.infer(bar, env)
  end

  test "infer function with variable assignments which get used in function calls" do
    str = """
    use test2

    fn foo(a:Int, b:Float) : Float do
      x = 123
      y = 456
      z = test2.div(test2.add(x, test2.add(y, a)), b)
    end
    """

    {:ok, ast} = Parser.parse_module(str)

    CodeServer.set_type(signature("test2", "div", [:Float, :Int]), {:ok, :Float})
    CodeServer.set_type(signature("test2", "div", [:Int, :Float]), {:ok, :Float})
    CodeServer.set_type(signature("test2", "add", [:Int, :Float]), {:ok, :Float})
    CodeServer.set_type(signature("test2", "add", [:Int, :Int]), {:ok, :Int})

    [function] = ast[:function_defs]

    assert {:ok, :Float} = TypeChecker.infer(function, %{})
    assert {:ok, :Float} = TypeChecker.check(function, %{})
  end

  test "infer function calls considering union types" do
    str = """
    use test2

    fn foo : :ok do
      test2.div(:a)
    end
    """

    {:ok, ast} = Parser.parse_module(str)

    arg_type = T.Union.new([:a, :b])
    CodeServer.set_type(signature("test2", "div", [arg_type]), {:ok, :ok})

    [function] = ast[:function_defs]

    assert {:ok, :ok} = TypeChecker.infer(function, %{})
  end

  describe "string" do
    test "string" do
      str = "\"Hello world\""

      ast = TestParser.expression!(str)

      assert {:ok, :String, _} = TypeChecker.infer_exp(%{}, ast)
    end

    test "parses string inside interpolation" do
      str = ~S"""
      "#{"test"}"
      """

      ast = TestParser.expression!(str)

      assert {:ok, :String, _} = TypeChecker.infer_exp(%{}, ast)
    end

    test "returns error when unknown variable in string interpolation" do
      str = ~S"""
      "#{x}"
      """

      ast = TestParser.expression!(str)

      assert {:error, "Unknown variable: x"} = TypeChecker.infer_exp(%{}, ast)
    end

    test "parses known variable in string interpolation" do
      str = ~S"""
      hello = "Hello"
      "#{hello}"
      """

      {:ok, ast, _, _, _, _} = TestParser.exps(str)

      env = TypeChecker.init_env(ast)

      assert {:ok, :String, _} = TypeChecker.infer_block(env, ast)
    end

    test "parses multiple string interpolation with expressions" do
      str = ~S"""
      hello = "Hello#{"!"}"
      "#{hello} Greetings to the #{"world!"}"
      """

      {:ok, ast, _, _, _, _} = TestParser.exps(str)

      env = TypeChecker.init_env(ast)

      assert {:ok, :String, _} = TypeChecker.infer_block(env, ast)
    end

    test "accepts only strings in interpolation" do
      str = ~S"""
      "#{1}"
      """

      ast = TestParser.expression!(str)

      assert {
               :error,
               "Expression used in string interpolation expected to be String, got Int"
             } = TypeChecker.infer_exp(%{}, ast)
    end
  end

  describe "lists" do
    test "list of integers" do
      str = "[1, 2, 3]"

      ast = TestParser.expression!(str)

      assert {:ok, %T.List{type: :Int}, _} = TypeChecker.infer_exp(%{}, ast)
    end

    test "list of integers and floats" do
      str = "[1, 2/3, 3]"

      ast = TestParser.expression!(str)

      assert {:error, "Elements of list have different types. Expected: Int, got: Float"} =
               TypeChecker.infer_exp(%{}, ast)
    end

    test "list of floats inferred from fn calls" do
      str = "[1/2, 2/3]"

      ast = TestParser.expression!(str)

      assert {:ok, %T.List{type: :Float}, _} = TypeChecker.infer_exp(%{}, ast)
    end

    test "List of strings" do
      str = "[\"foo\", \"bar\"]"

      ast = TestParser.expression!(str)

      assert {:ok, %T.List{type: :String}, _} = TypeChecker.infer_exp(%{}, ast)
    end

    test "List of list of integers" do
      str = "[[1, 2], [3, 4]]"

      ast = TestParser.expression!(str)

      assert {:ok, %T.List{type: %T.List{type: :Int}}, _} = TypeChecker.infer_exp(%{}, ast)
    end

    test "empty list" do
      str = "[]"

      ast = TestParser.expression!(str)

      assert {:ok, %T.List{type: nil}, _} = TypeChecker.infer_exp(%{}, ast)
    end
  end

  describe "tuples" do
    test "tuple of integers" do
      str = "{1, 2, 3}"

      ast = TestParser.expression!(str)

      assert {:ok, %T.Tuple{elements: [:Int, :Int, :Int]}, _env} = TypeChecker.infer_exp(%{}, ast)
    end

    test "tuple of integers and floats" do
      str = "{1, 2/3, 3}"

      ast = TestParser.expression!(str)

      assert {:ok, %T.Tuple{elements: [:Int, :Float, :Int]}, _env} =
               TypeChecker.infer_exp(%{}, ast)
    end

    test "tuple of floats inferred from fn calls" do
      str = "{1/2, 2/3}"

      ast = TestParser.expression!(str)

      assert {:ok, %T.Tuple{elements: [:Float, :Float]}, _env} = TypeChecker.infer_exp(%{}, ast)
    end

    test "tuple of strings" do
      str = ~s({"foo", "bar"})

      ast = TestParser.expression!(str)

      assert {:ok, %T.Tuple{elements: [:String, :String]}, _env} = TypeChecker.infer_exp(%{}, ast)
    end

    test "tuple of tuple of mixed types" do
      str = ~s({{1, 2/5}, {"3", true}})

      ast = TestParser.expression!(str)

      assert {:ok,
              %T.Tuple{
                elements: [
                  %T.Tuple{elements: [:Int, :Float]},
                  %T.Tuple{elements: [:String, :Bool]}
                ]
              }, _env} = TypeChecker.infer_exp(%{}, ast)
    end
  end

  describe "record" do
    test "unnamed record" do
      str = "{foo: 123, bar: \"Baz\"}"

      ast = TestParser.expression!(str)

      assert {:ok, %T.Record{fields: [bar: :String, foo: :Int]}, _} =
               TypeChecker.infer_exp(%{}, ast)
    end

    test "error" do
      str = "{foo: x, bar: \"Baz\"}"

      ast = TestParser.expression!(str)

      assert {:error, "Unknown variable: x"} = TypeChecker.infer_exp(%{}, ast)
    end
  end

  describe "map" do
    test "type check for a valid expression" do
      str = ~s({"foo" => 123, "bar" => 345})

      ast = TestParser.expression!(str)

      assert {:ok, %T.Map{key_type: :String, value_type: :Int}, _} =
               TypeChecker.infer_exp(%{}, ast)
    end

    test "type check for map with mixed type" do
      str = ~s({1 => [1, 2], "foo" => 345})

      ast = TestParser.expression!(str)

      assert {:error, "Expected map key of type Int, but got String"} =
               TypeChecker.infer_exp(%{}, ast)

      str = ~s({"foo" => [1, 2], "bar" => 345})

      ast = TestParser.expression!(str)

      assert {:error, "Expected map value of type List(Int), but got Int"} =
               TypeChecker.infer_exp(%{}, ast)
    end
  end

  describe "function reference" do
    test "with args" do
      str = """
      use bar
      &bar.sum(Int, Int)
      """

      {:ok, [_, ast], _, _, _, _} = TestParser.exp_with_expanded_modules(str)

      CodeServer.set_type(signature("bar", "sum", [:Int, :Int]), {:ok, :Int})

      assert {:ok,
              %T.FunctionRef{
                arg_types: [:Int, :Int],
                return_type: :Int
              }, _} = TypeChecker.infer_exp(%{}, ast)
    end

    test "without args" do
      str = """
      use bar
      &bar.sum
      """

      {:ok, [_, ast], _, _, _, _} = TestParser.exp_with_expanded_modules(str)

      CodeServer.set_type(signature("bar", "sum", []), {:ok, :Int})

      assert {:ok, %T.FunctionRef{arg_types: [], return_type: :Int}, _} =
               TypeChecker.infer_exp(%{}, ast)
    end
  end

  describe "boolean" do
    test "true" do
      str = "true"
      ast = TestParser.expression!(str)

      assert {:ok, :Bool, _} = TypeChecker.infer_exp(%{}, ast)
    end

    test "false" do
      str = "false"
      ast = TestParser.expression!(str)

      assert {:ok, :Bool, _} = TypeChecker.infer_exp(%{}, ast)
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

      assert {
               :error,
               "Wrong type for if condition. Expected: Bool, Got: String"
             } = TypeChecker.infer_exp(%{}, ast)
    end

    test "completes when if and else blocks have same return types" do
      str = """
      if true do
        "done"
      else
        "500"
      end
      """

      ast = TestParser.expression!(str)

      assert {:ok, :String, _env} = TypeChecker.infer_exp(%{}, ast)
    end

    test "completes when if and else blocks have different return types" do
      str = """
      if false do
        "done"
      else
        500
      end
      """

      ast = TestParser.expression!(str)
      types = MapSet.new([:String, :Int])
      assert {:ok, %T.Union{types: ^types}, _env} = TypeChecker.infer_exp(%{}, ast)
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
      env = TypeChecker.init_env(ast)

      assert {:ok, :String, _env} = TypeChecker.infer_exp(env, ast)
    end
  end

  describe "case expression" do
    test "when patterns match" do
      str = """
      case {:ok, 123} do
        {:ok, 1} -> 1
        {:ok, x} -> "x"
      end
      """

      ast = TestParser.expression!(str)
      env = TypeChecker.init_env(ast)

      expected_type = T.Union.new([:Int, :String])
      assert {:ok, ^expected_type, _env} = TypeChecker.infer_exp(env, ast)
    end

    test "when patterns match a union type" do
      str = """
      e =
        if true do
          {:ok, 123}
        else
          {:error, "Message"}
        end

      case e do
        {:ok, x} -> x
        {:error, str} -> 0
      end
      """

      {:ok, ast, _, _, _, _} = TestParser.exps(str)
      env = TypeChecker.init_env(ast)
      assert {:ok, :Int, _} = TypeChecker.infer_block(env, ast)
    end

    test "when patterns are not exhaustive" do
      str = """
      e =
        if true do
          {:ok, 123}
        else
          {:error, "Message"}
        end

      case e do
        {:ok, x} -> x
      end
      """

      {:ok, ast, _, _, _, _} = TestParser.exps(str)
      env = TypeChecker.init_env(ast)
      assert {:error, "Missing pattern: {error, String}"} = TypeChecker.infer_block(env, ast)
    end

    test "when a pattern does not match" do
      str = """
      case 123 do
        "hello" -> :ok
      end
      """

      {:ok, ast, _, _, _, _} = TestParser.exps(str)
      env = TypeChecker.init_env(ast)
      assert {:error, "Non-matching pattern"} = TypeChecker.infer_block(env, ast)
    end
  end

  describe "function calls using reference" do
    test "valid reference" do
      str = """
      use test2

      fn foo do
        x = &test2.bar(String, Int)
        x.("hello", 123)
      end
      """

      {:ok, ast} = Parser.parse_module(str)

      CodeServer.set_type(signature("test2", "bar", [:String, :Int]), {:ok, :Bool})

      [function] = ast[:function_defs]

      assert {:ok, :Bool} = TypeChecker.infer(function, %{})
    end

    test "when function returns is expected to return a union type and has if-else clause" do
      str = """
      use test2

      fn foo(x: String, y: Int) : :ok | :error do
        f = &test2.bar(String, Int)
        if f.(x, y) do
          :ok
        else
          :error
        end
      end
      """

      {:ok, ast} = Parser.parse_module(str)
      CodeServer.set_type(signature("test2", "bar", [:String, :Int]), {:ok, :Bool})
      types = MapSet.new([:ok, :error])
      [function] = ast[:function_defs]

      assert {:ok, %T.Union{types: ^types}} = TypeChecker.infer(function, %{})
    end

    test "when function accepts union types and calls a function ref" do
      str = """
      use test2

      fn foo(x: String, y: Int) : :ok | :error do
        f = &test2.bar(String, Int)
        f.(x, y)
      end
      """

      {:ok, ast} = Parser.parse_module(str)
      [function] = ast[:function_defs]
      env = TypeChecker.init_env(ast)

      types = MapSet.new([:error, :ok])

      CodeServer.set_type(
        signature("test2", "bar", [:String, :Int]),
        {:ok, %T.Union{types: types}}
      )

      assert {:ok, %T.Union{types: ^types}} = TypeChecker.infer(function, env)
      assert {:ok, %T.Union{types: ^types}} = TypeChecker.check(function, env)
    end

    test "identifier is not a reference" do
      str = """
      fn foo do
        x = 123
        x.()
      end
      """

      {:ok, ast} = Parser.parse_module(str)

      [function] = ast[:function_defs]

      assert {:error, "Expected a function reference, but got type: Int"} =
               TypeChecker.infer(function, %{})
    end

    test "function ref when given wrong types" do
      str = """
      use test2

      fn foo do
        x = &test2.bar(String, Int)
        x.(123)
      end
      """

      {:ok, ast} = Parser.parse_module(str)
      [function] = ast[:function_defs]
      CodeServer.set_type(signature("test2", "bar", [:String, :Int]), {:ok, :Bool})

      error =
        "Expected function reference to be called with arguments (String, Int), but it was called with arguments (Int)"

      assert {:error, ^error} = TypeChecker.infer(function, %{})
    end
  end

  describe "effect" do
    test "io.gets" do
      str = "io.gets(\"Hello\")"

      ast = TestParser.expression!(str)

      assert {:ok, :String, %{has_effect: true}} = TypeChecker.infer_exp(%{}, ast)
    end

    test "functions with effects inside them become effectful" do
      str = """
      fn foo : Effect(String) do
        x = io.gets("Enter your name")
        "Hello #\{x}"
      end
      """

      {:ok, ast} = Parser.parse_module(str)

      [function] = ast[:function_defs]

      assert {:ok, %T.Effect{type: :String}} = TypeChecker.infer(function, %{})
      assert {:ok, %T.Effect{type: :String}} = TypeChecker.check(function, %{})
    end

    test "function with multiple effects" do
      str = """
      use test

      fn foo : Effect(Int) do
        x = io.gets("Enter your name")
        test.to_int(x)
      end
      """

      {:ok, ast} = Parser.parse_module(str)
      CodeServer.set_type(signature("test", "to_int", [:String]), {:ok, %T.Effect{type: :Int}})

      [function] = ast[:function_defs]

      assert {:ok, %T.Effect{type: :Int}} = TypeChecker.infer(function, %{})
      assert {:ok, %T.Effect{type: :Int}} = TypeChecker.check(function, %{})
    end

    test "effectful function ref call" do
      str = """
      use test2

      fn foo : Effect(String) do
        f = &test2.bar
        f.()
      end
      """

      {:ok, ast} = Parser.parse_module(str)
      [function] = ast[:function_defs]
      env = TypeChecker.init_env(ast)

      CodeServer.set_type(signature("test2", "bar", []), {:ok, %T.Effect{type: :String}})

      assert {:ok, %T.Effect{type: :String}} = TypeChecker.infer(function, env)
      assert {:ok, %T.Effect{type: :String}} = TypeChecker.check(function, env)
    end
  end

  describe "anonymous function" do
    test "with arg types" do
      str = """
      (x: Int, y: Int) do
        x + y
      end
      """

      ast = TestParser.expression!(str)

      assert {:ok,
              %T.FunctionRef{
                arg_types: [:Int, :Int],
                return_type: :Int
              }, _} = TypeChecker.infer_exp(%{}, ast)
    end
  end

  describe "generics" do
    test "multiple type variables" do
      str = """
      fn foo(list: List(a), fun: Fn(List(a) -> List(b))) do
        fun.(list)
      end
      """

      {:ok, ast} = Parser.parse_module(str)

      [function] = ast[:function_defs]

      assert {:ok, %T.List{type: "b"}} = TypeChecker.infer(function, %{})
    end

    test "can't call incompatible functions on type variables" do
      str = """
      fn foo(x: a) do
        x + 100
      end
      """

      {:ok, ast} = Parser.parse_module(str)

      [function] = ast[:function_defs]

      assert {:error, "Function fika/kernel.+(a, Int) does not exist"} =
               TypeChecker.infer(function, %{})
    end

    test "infers return types of functions with type variables" do
      str = """
      fn foo(x: a) : a do
        x
      end

      fn bar do
        foo(123)
      end
      """

      {:ok, ast} = Parser.parse_module(str)

      [_foo, bar] = ast[:function_defs]

      assert {:ok, :Int} = TypeChecker.infer(bar, %{ast: ast})
    end

    test "infers return types of functions when type variables are passed as args" do
      str = """
      fn foo(x: a) do
        case 123 do
          123 -> x
          y -> "Hello"
        end
      end

      fn bar(x: z) do
        foo(x)
      end
      """

      {:ok, ast} = Parser.parse_module(str)

      [_foo, bar] = ast[:function_defs]

      assert TypeChecker.infer(bar, %{ast: ast}) == {:ok, T.Union.new([:String, "z"])}
    end

    test "type variables used in function ref calls" do
      str = """
      fn foo(x: a) do
        case 123 do
          123 -> x
          y -> "Hello"
        end
      end

      fn bar(x: Fn(b -> b | String | Int), z: b) do
        x.(z)
      end

      fn baz(x: c) do
        bar(&foo(c), x)
      end
      """

      {:ok, ast} = Parser.parse_module(str)

      [_foo, _bar, baz] = ast[:function_defs]

      assert TypeChecker.infer(baz, %{ast: ast}) == {:ok, T.Union.new([:String, "c", :Int])}
    end
  end

  defp signature(m, f, t) do
    %FunctionSignature{module: m, function: f, types: t}
  end
end
