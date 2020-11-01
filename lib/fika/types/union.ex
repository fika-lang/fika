defmodule Fika.Types.Union do
  defstruct [:types]

  defimpl String.Chars, for: Fika.Types.Union do
    def to_string(%{types: types}) do
      Enum.join(types, " | ")
    end
  end
end
