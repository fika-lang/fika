defmodule Fika.Types.ArgList do
  @moduledoc """
  Helper module for converting arg lists to strings
  """
  defstruct value: []

  defimpl String.Chars, for: Fika.Types.ArgList do
    def to_string(%{value: value}) do
      Enum.join(value, ", ")
    end
  end
end
