defmodule Fika.Types.Union do
  defstruct [:types]

  def flatten_types(types) when is_list(types) do
    Enum.flat_map(types, fn
      %__MODULE__{types: t} ->
        flatten_types(t)

      t ->
        [t]
    end)
  end

  defimpl String.Chars, for: Fika.Types.Union do
    def to_string(%{types: types}) do
      Enum.join(types, " | ")
    end
  end
end
