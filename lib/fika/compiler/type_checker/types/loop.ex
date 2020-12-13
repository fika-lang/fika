defmodule Fika.Compiler.TypeChecker.Types.Loop do
  @moduledoc """
  Defines when a function may not terminate due to recursion
  """
  defstruct type: :Nothing

  alias Fika.Compiler.TypeChecker.Types, as: T

  def new(), do: %__MODULE__{}
  def new([]), do: %__MODULE__{}
  def new([type]), do: %__MODULE__{type: type}
  def new(type), do: %__MODULE__{type: type}

  def is_loop(%__MODULE__{}), do: true
  def is_loop(_), do: false

  def is_empty_loop(%__MODULE__{type: :Nothing}), do: true
  def is_empty_loop(_), do: false

  defimpl String.Chars, for: T.Loop do
    def to_string(%{type: type}) do
      "Loop(#{type})"
    end
  end
end
