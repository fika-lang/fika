defmodule Fika.Compiler.TypeChecker.SequentialTypeChecker do
  alias Fika.Compiler.TypeChecker

  def get_result(signature, env) do
    if function = find_by_signature(env.ast[:function_defs], signature) do
      TypeChecker.infer(function, env)
    else
      {:error, "Function #{signature} not found"}
    end
  end

  defp find_by_signature(function_defs, signature) do
    Enum.find(function_defs, fn function ->
      signature.module
      |> TypeChecker.function_ast_signature(function)
      |> TypeChecker.signature_matches_call?(signature)
    end)
  end
end
