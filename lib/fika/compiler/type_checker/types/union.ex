defmodule Fika.Compiler.TypeChecker.Types.Union do
  defstruct types: MapSet.new()

  @type t :: %__MODULE__{types: MapSet.t()}

  alias Fika.Compiler.TypeChecker.Types, as: T

  @spec new(types :: Enumerable.t()) :: any()
  def new(nested_types) do
    types = flatten_types(nested_types)

    # We need to unnest loops because they can emerge upon recursive calls
    case Enum.split_with(types, &T.Loop.is_loop/1) do
      {_loops = [], _base_types} ->
        %__MODULE__{types: types}

      {_loops, []} ->
        T.Loop.new()

      {_loops, [type]} ->
        T.Loop.new(type)

      {_loops, base_types} ->
        T.Loop.new(%__MODULE__{types: MapSet.new(base_types)})
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
    |> MapSet.new()
  end

  defimpl String.Chars, for: Fika.Compiler.TypeChecker.Types.Union do
    def to_string(%{types: types}) do
      Enum.join(types, " | ")
    end
  end
end
