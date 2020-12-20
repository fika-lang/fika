defmodule Fika.Compiler.TypeChecker.FunctionDependencies do
  @moduledoc """
  This module keeps track of dependencies between functions.

  The main usage for this is so we can avoid deadlocks in the
  parallel compiler when there's recursion involved.
  """

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    {:ok, initial_state()}
  end

  @doc false
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @doc false
  def get_dependency_graph do
    GenServer.call(__MODULE__, :get_dependency_graph, timeout())
  end

  defp initial_state do
    %{graph: :digraph.new()}
  end

  @spec set(source :: String.t() | nil, target :: String.t() | nil) ::
          :ok | {:error, :cycle_encountered}
  def set(source, target) do
    GenServer.call(__MODULE__, {:set, source, target}, timeout())
  end

  def handle_call(:reset, _from, _state) do
    {:reply, :ok, initial_state()}
  end

  def handle_call(:get_dependency_graph, _from, %{graph: graph} = state) do
    vertices = graph |> :digraph.vertices() |> Enum.sort()
    edges = graph |> :digraph.edges() |> Enum.sort()

    deps = %{vertices: vertices, edges: edges}

    {:reply, deps, state}
  end

  def handle_call({:set, source, target}, _from, state)
      when is_nil(source) or is_nil(target) do
    {:reply, :ok, state}
  end

  def handle_call({:set, source, target}, _from, %{graph: current_graph} = state) do
    graph =
      current_graph
      |> add_vertex(source)
      |> add_vertex(target)
      |> add_edge(source, target)

    response =
      if :digraph.get_cycle(graph, source) do
        {:error, :cycle_encountered}
      else
        :ok
      end

    updated_state = Map.put(state, :graph, graph)

    {:reply, response, updated_state}
  end

  defp add_vertex(graph, v) do
    :digraph.add_vertex(graph, v, v)
    graph
  end

  defp add_edge(graph, source, target) do
    edge = {source, target}

    :digraph.add_edge(graph, edge, source, target, edge)
    graph
  end

  defp timeout do
    :fika
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:genserver_timeout, 5_000)
  end
end
