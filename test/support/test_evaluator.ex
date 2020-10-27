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
  #        {:ok, {7, _}} = eval("1 + a * 3", [{:a, "Int", 2}])
  #      end
  #
  #   2) test "match operator" do
  #        {:ok, {5, [a: 5]}} = eval("a = 5")
  #      end
  #
  #   3) test "new line before binary op makes for two expressions" do
  #        {:error, "expected end of string", "+3", _, _, _} = eval("2\n+3")
  #      end
  def eval(str, bindings \\ []) do
    with {:ok, [ast], _, _, _, _} <- TestParser.expression(str),
         {:ok, type, _env} <- check_types(ast, bindings),
         forms <- ErlTranslate.translate_expression(ast) do
      {:ok, {result, new_bindings}} = eval_forms(forms, untyped_bindings(bindings))
      {:ok, {result, type, new_bindings}}
    end
  end

  # Evaluates the Erlang abs form of an expression.
  #
  # Usage example:
  #   test "erlang forms" do
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
  #     {:ok, {"Hello World", _}} = eval(exp_ast)
  #   end
  def eval_forms(forms, bindings \\ []) do
    try do
      {:value, result, new_bindings} = :erl_eval.expr(forms, bindings)
      {:ok, {result, new_bindings}}
    rescue
      _ -> {:error, "Bad Erlang forms"}
    end
  end

  defp untyped_bindings(bindings) do
    Enum.map(bindings, fn {name, _type, value} -> {name, value} end)
  end

  defp check_types(ast, bindings) do
    env = Env.init_module_env(Env.init(), :tmp, ast)

    env_from_bindings =
      Enum.reduce_while(bindings, {:ok, env}, fn {name, expected_type, value}, {:ok, env} ->
        parsed_binding = TestParser.expression!("#{value}")

        case TypeChecker.infer_exp(env, parsed_binding) do
          {:ok, ^expected_type, _env} ->
            {:cont, {:ok, Env.scope_add(env, name, expected_type)}}

          {:ok, other_type, _env} ->
            {:halt, {:error, "Declared binding type: #{expected_type}, got: #{other_type}"}}

          error ->
            {:halt, error}
        end
      end)

    case env_from_bindings do
      {:ok, env} -> TypeChecker.infer_exp(env, ast)
      error -> error
    end
  end
end
