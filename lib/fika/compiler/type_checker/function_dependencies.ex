defmodule Fika.Compiler.TypeChecker.FunctionDependencies do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> MapSet.new() end, name: __MODULE__)
  end

  @spec set(f :: any, g :: any) :: :ok | {:error, :cycle_encountered}

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
