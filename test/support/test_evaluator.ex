defmodule TestEvaluator do
  alias Fika.{
    Env,
    TypeChecker,
    ErlTranslate
  }

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
  def eval(str, bindings \\ []) do
    {:value, evaluated, new_bindings} =
      TestParser.expression!(str)
      |> check_types(bindings)
      |> ErlTranslate.translate_expression()
      |> :erl_eval.expr(to_erl_bindings(bindings))

    {evaluated, new_bindings}
  end

  defp to_erl_bindings(bindings) do
    Enum.map(bindings, fn {name, _type, value} -> {name, value} end)
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
