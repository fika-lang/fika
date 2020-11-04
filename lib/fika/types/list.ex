defmodule Fika.Types.List do
  defstruct type: :Nothing

  defimpl String.Chars, for: Fika.Types.List do
    def to_string(%{type: type}) do
      "List(#{type})"
    end
  end
end
