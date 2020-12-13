defmodule Fika.Compiler.TypeChecker.FunctionDependencies do
  @moduledoc """
  This module keeps track of dependencies between functions.

  The main usage for this is so we can avoid deadlocks in the
  parallel compiler when there's recursion involved.
  """

  use Agent

  def start_link(_) do
    Agent.start_link(&initial_state/0, name: __MODULE__)
  end

  @doc false
  def reset do
    Agent.update(__MODULE__, fn _ -> initial_state() end)
  end

  defp initial_state do
    %{}
  end

  @spec set(source :: String.t() | nil, target :: String.t() | nil) ::
          :ok | {:error, :cycle_encountered}
  def set(source, target)

  def set(source, target) when is_nil(source) or is_nil(target) do
    :ok
  end

  def set(source, target) do
    Agent.update(__MODULE__, fn state ->
      deps =
        state
        |> Map.get(source, MapSet.new())
        |> MapSet.put(target)

      Map.put(state, source, deps)
    end)

    dependencies = Agent.get(__MODULE__, & &1)

    # Check if after adding {source, target}, we can find a cycle
    if check_cycle(dependencies, target) do
      {:error, :cycle_encountered}
    else
      :ok
    end
  end

  @doc false
  def check_cycle(dependencies, node, travelled_nodes \\ MapSet.new()) do
    targets = Map.get(dependencies, node, MapSet.new())

    Enum.any?(targets, fn target ->
      if target in travelled_nodes do
        true
      else
        check_cycle(dependencies, node, MapSet.put(travelled_nodes, target))
      end
    end)
  end
end
