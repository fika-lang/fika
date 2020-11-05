defmodule Fika.Compiler.TypeChecker.Types.Map do
  defstruct [:key_type, :value_type]

  alias Fika.Compiler.TypeChecker.Types, as: T

  defimpl String.Chars, for: T.Map do
    def to_string(%{key_type: key_type, value_type: value_type}) do
      "Map(#{key_type}, #{value_type})"
    end
  end
end
