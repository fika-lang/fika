defmodule Fika.Types.FunctionRef do
  defstruct [:return_type, arg_types: %Fika.Types.ArgList{}]

  defimpl String.Chars, for: Fika.Types.FunctionRef do
    def to_string(%{arg_types: arg_types, return_type: return_type}) do
      "Fn(#{arg_types}->#{return_type})"
    end
  end
end
