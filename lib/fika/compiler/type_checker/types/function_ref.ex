defmodule Fika.Compiler.TypeChecker.Types.FunctionRef do
  defstruct [:return_type, arg_types: []]

  alias Fika.Compiler.TypeChecker.Types, as: T

  defimpl String.Chars, for: T.FunctionRef do
    def to_string(%{arg_types: arg_types, return_type: return_type}) do
      arg_types_str = T.Helper.join_list(arg_types)
      "Fn(#{arg_types_str}->#{return_type})"
    end
  end
end
