defmodule Fika.Compiler.TypeChecker.Types.Union do
  defstruct types: MapSet.new()

  @type t :: %__MODULE__{types: MapSet.t()}

  alias Fika.Compiler.TypeChecker.Types, as: T

  @spec new(types :: Enumerable.t()) :: any()
  def new(nested_types) do
    {has_loop, expanded_types} = find_and_expand_loops(nested_types)

    types = flatten_types(expanded_types)

    cond do
      Enum.count(types) < 2 and has_loop ->
        types
        |> Enum.to_list()
        |> T.Loop.new()

      has_loop ->
        T.Loop.new(%__MODULE__{types: types})

      true ->
        # There were no loops and we have more types to begin with
        %__MODULE__{types: types}
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

  @spec find_and_expand_loops(types :: Enumerable.t()) ::
          {has_loop :: boolean(), types :: MapSet.t()}
  @doc false
  def find_and_expand_loops(types) do
    expanded_types =
      types
      |> Enum.reject(&T.Loop.is_empty_loop/1)
      |> MapSet.new(fn
        %T.Loop{type: t} ->
          t

        t ->
          t
      end)

    has_loop = Enum.any?(types, &T.Loop.is_loop/1)

    {has_loop, expanded_types}
  end

  defimpl String.Chars, for: Fika.Compiler.TypeChecker.Types.Union do
    def to_string(%{types: types}) do
      Enum.join(types, " | ")
    end
  end
end
