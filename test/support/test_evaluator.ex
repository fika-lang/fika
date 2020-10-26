defmodule TestEvaluator do
  alias Fika.{
    Env,
    TypeChecker,
    ErlTranslate
  }

  def eval(code, bindings \\ [])

  # Evaluates a string representing an expression.
  #
  # Usage examples:
  #   1) test "add has less precedence than mult" do
  #        {7, _} = eval("1 + a * 3", [{:a, "Int", 2}])
  #      end
  #
  #   2) test "match operator" do
  #        {5, [a: 5]} = eval("a = 5")
  #      end
  def eval(str, bindings) when is_binary(str) do
    case TestParser.expression(str) do
      {:ok, [parsed], _, _, _, _} ->
        parsed
        |> check_types(bindings)
        |> ErlTranslate.translate_expression()
        |> eval(Enum.map(bindings, fn {name, _type, value} -> {name, value} end))

      err ->
        err
    end
  end

  # Evaluates a piece of AST representing an expression.
  #
  # Usage example:
  #   test "erlang ast" do
  #     exp_ast = {
  #       :bin,
  #       1,
  #       [
  #         {:bin_element, 1, {:string, 1, 'Hello'}, :default, :default},
  #         {:bin_element, 1, {:string, 1, ' '}, :default, :default},
  #         {:bin_element, 1, {:string, 1, 'World'}, :default, :default}
  #       ]
  #     }
  #
  #     {"Hello World", _} = eval(exp_ast)
  #   end
  def eval(ast, bindings) when is_tuple(ast) do
    {:value, evaluated, new_bindings} = :erl_eval.expr(ast, bindings)
    {evaluated, new_bindings}
  end

  defp check_types(ast, bindings) do
    env = Env.init_module_env(Env.init(), :tmp, ast)

    {:ok, env} =
      Enum.reduce(bindings, {:ok, env}, fn {name, type, value}, {:ok, env} ->
        parsed_binding = TestParser.expression!("#{value}")

        case TypeChecker.infer_exp(env, parsed_binding) do
          {:ok, ^type, _env} ->
            {:ok, Env.scope_add(env, name, type)}

          err ->
            err
        end
      end)

    {:ok, _type, _env} = TypeChecker.infer_exp(env, ast)

    ast
  end
end
