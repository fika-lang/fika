defmodule Fika.Types.Atom do
  defstruct [:value]

  defimpl String.Chars, for: Fika.Types.Atom do
    def to_string(%{value: value}) do
      ":#{value}"
    end
  end
end
