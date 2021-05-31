defmodule Fika.Compiler.TypeChecker.Types.Union do
  defstruct types: MapSet.new()

  @type t :: %__MODULE__{types: MapSet.t()}

  @spec new(types :: Enumerable.t()) :: t()
  def new(types) do
    union = %__MODULE__{types: flatten_types(types)}

    if MapSet.size(union.types) == 1 do
      Enum.at(union.types, 0)
    else
      union
    end
  end

  @spec flatten_types(types :: Enumerable.t()) :: MapSet.t()
  @doc false
  def flatten_types(types) do
    types
    |> Enum.flat_map(fn
      %__MODULE__{types: t} ->
        flatten_types(t)

      t ->
        [t]
    end)
    |> List.flatten()
    |> MapSet.new()
  end

  def to_list(types) do
    MapSet.to_list(types)
  end

  defimpl String.Chars, for: Fika.Compiler.TypeChecker.Types.Union do
    def to_string(%{types: types}) do
      Enum.join(types, " | ")
    end
  end
end
