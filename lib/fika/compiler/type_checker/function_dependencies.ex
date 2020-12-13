defmodule Fika.Compiler.TypeChecker.FunctionDependencies do
  @moduledoc """
  This module keeps track of dependencies between functions.

  The main usage for this is so we can avoid deadlocks in the
  parallel compiler when there's recursion involved.
  """

  use Agent

  def start_link(_) do
    Agent.start_link(fn -> MapSet.new() end, name: __MODULE__)
  end

  @spec set(f :: String.t() | nil, g :: String.t() | nil) :: :ok | {:error, :cycle_encountered}
  def set(f, g)

  def set(f, g) when is_nil(f) or is_nil(g) do
    :ok
  end

  def set(f, g) do
    Agent.update(__MODULE__, fn state -> MapSet.put(state, {f, g}) end)

    if Agent.get(__MODULE__, fn state -> {g, f} in state end) do
      {:error, :cycle_encountered}
    else
      :ok
    end
  end
end
