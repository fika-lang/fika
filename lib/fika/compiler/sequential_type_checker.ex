defmodule Fika.Compiler.SequentialTypeChecker do
  alias Fika.{
    TypeChecker
  }

  def get_result(signature, env) do
    if function = find_by_signature(env.ast[:function_defs], signature) do
      TypeChecker.infer(function, env)
    else
      {:error, "Function #{signature} not found"}
    end
  end

  defp find_by_signature(function_defs, signature) do
    Enum.find(function_defs, fn function ->
      TypeChecker.function_ast_signature(function) == signature
    end)
  end
end
