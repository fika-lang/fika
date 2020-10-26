defmodule TestEvaluator do
  alias Fika.ErlTranslate

  def eval(code, bindings \\ [])

  # Evaluates a string representing an expression.
  #
  # Usage examples:
  #   1) test "add has less precedence than mult" do
  #        {7, _} = eval("1 + a * 3", [{:a, 2}])
  #      end
  #
  #   2) test "match operator" do
  #        {5, [a: 5]} = eval("a = 5")
  #      end
  def eval(str, bindings) when is_binary(str) do
    case TestParser.expression(str) do
      {:ok, [parsed], _, _, _, _} ->
        parsed
        |> ErlTranslate.translate_expression()
        |> eval(bindings)

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
end
