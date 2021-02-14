defmodule Fika.Compiler.TypeChecker.Types.List do
  defstruct type: nil

  defimpl String.Chars, for: Fika.Compiler.TypeChecker.Types.List do
    def to_string(%{type: type}) do
      "List(#{type})"
    end
  end
end
