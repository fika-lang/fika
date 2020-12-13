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

  @spec set(source :: String.t() | nil, target :: String.t() | nil) ::
          :ok | {:error, :cycle_encountered}
  def set(source, target)

  def set(source, target) when is_nil(source) or is_nil(target) do
    :ok
  end

  def set(source, target) do
    Agent.update(__MODULE__, fn state -> MapSet.put(state, {source, target}) end)

    dependencies = Agent.get(__MODULE__, & &1)

    # Check if after adding {source, target}, we can find a cycle
    if check_cycle(dependencies, [target], target) do
      {:error, :cycle_encountered}
    else
      :ok
    end
  end

  @doc false
  def check_cycle(dependencies, travelled_nodes, node) do
    if node in travelled_nodes do
      true
    else
      targets = Enum.find(dependencies, fn {source, _} -> source == node end)

      Enum.any?(targets, fn target ->
        check_cycle(dependencies, [target | travelled_nodes], node)
      end)
    end
  end
end
