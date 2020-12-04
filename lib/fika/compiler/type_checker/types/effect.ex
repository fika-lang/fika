defmodule Fika.Compiler.TypeChecker.Types.Effect do
  defstruct type: :Nothing

  alias Fika.Compiler.TypeChecker.Types, as: T

  defimpl String.Chars, for: T.Effect do
    def to_string(%{type: type}) do
      "Effect(#{type})"
    end
  end
end
