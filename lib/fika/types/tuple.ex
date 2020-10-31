defmodule Fika.Types.Tuple do
  defstruct elements: %Fika.Types.ArgList{}

  defimpl String.Chars, for: Fika.Types.Tuple do
    def to_string(%{elements: elements}) do
      "{#{elements}}"
    end
  end
end
