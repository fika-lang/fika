defmodule Fika.Types.Union do
  defstruct [:types]

  def check_equality(%__MODULE__{types: this} = left, %__MODULE__{types: that} = right) do
    this_set = this |> flatten_types() |> MapSet.new()
    that_set = that |> flatten_types() |> MapSet.new()

    if this_set == that_set do
      :ok
    else
      {:error, {:different_types, left, right}}
    end
  end

  def check_equality(%__MODULE__{} = left, right), do: {:error, {:different_types, left, right}}
  def check_equality(left, %__MODULE__{} = right), do: {:error, {:different_types, left, right}}

  defp flatten_types(types) when is_list(types) do
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
