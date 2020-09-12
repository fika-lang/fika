defmodule Fika.TypeCheckerTest do
  use ExUnit.Case
  alias Fika.{
    Env,
    TypeChecker
  }

  test "infer type of integer literals" do
    str = "123"

    {:ok, [ast], _, _, _, _} = Fika.Parser.expression(str)

    assert {:ok, :Int, _} = TypeChecker.infer_exp(Env.init(), ast)
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
end
