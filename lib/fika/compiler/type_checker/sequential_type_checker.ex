defmodule Fika.Compiler.TypeChecker.SequentialTypeChecker do
  alias Fika.Compiler.TypeChecker
  alias Fika.Compiler.TypeChecker.FunctionMatch

  def get_result(signature, env) do
    if result = find_by_signature(env.ast[:function_defs], signature) do
      {function, vars} = result

      function
      |> TypeChecker.infer(env)
      |> FunctionMatch.replace_vars(vars)
    else
      {:error, "Function #{signature} not found"}
    end
  end

  defp find_by_signature(function_defs, signature) do
    Enum.find_value(function_defs, fn function ->
      vars =
        signature.module
        |> TypeChecker.function_ast_signature(function)
        |> FunctionMatch.match_signatures(signature)

      if vars do
        {function, vars}
      end
    end)
  end
end
