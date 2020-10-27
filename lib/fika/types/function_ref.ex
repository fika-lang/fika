defmodule Fika.Types.FunctionRef do
  defstruct [:arg_types, :return_type]

  defimpl String.Chars, for: Fika.Types.FunctionRef do
    def to_string(%{arg_types: arg_types, return_type: return_type}) do
      args = Enum.join(arg_types, ",")
      "Fn(#{args}->#{return_type})"
    end
  end
end
