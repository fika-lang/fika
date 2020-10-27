defmodule Fika.Types.Tuple do
  defstruct [:elements]

  defimpl String.Chars, for: Fika.Types.Tuple do
    def to_string(%{elements: elements}) do
      str =
        elements
        |> Enum.join(", ")

      "{" <> str <> "}"
    end
  end
end
