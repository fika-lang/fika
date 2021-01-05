defmodule Fika.Compiler.FunctionSignature do
  defstruct [:module, :function, types: []]

  alias Fika.Compiler.TypeChecker.Types, as: T

  defimpl String.Chars, for: __MODULE__ do
    def to_string(%{module: m, function: f, types: ts}) do
      types_str = T.Helper.join_list(ts)
      "#{m}.#{f}(#{types_str})"
    end
  end
end
