defmodule Fika.Compiler.CodeServer.FunctionDependencies do
  alias Fika.Compiler.FunctionSignature

  def new_graph, do: :digraph.new()

  @spec set_function_dependency(
          graph :: :digraph.graph(),
          source_function :: FunctionSignature.t(),
          sink_function :: FunctionSignature.t()
        ) :: :digraph.graph()
  def set_function_dependency(graph, source_function, sink_function) do
    graph
    |> add_vertex(source_function)
    |> add_vertex(sink_function)
    |> add_edge(source_function, sink_function)
    |> check_cycle(source_function, sink_function)
  end

  def check_cycle(graph, source_function, sink_function) do
    vertices = :digraph.get_cycle(graph, source_function)

    if vertices && sink_function in vertices do
      {:error, :cycle_encountered}
    else
      :ok
    end
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
end
