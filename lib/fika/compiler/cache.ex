defmodule Fika.Compiler.Cache do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> init_state() end, name: __MODULE__)
  end

  def all_paths do
    Agent.get(__MODULE__, &Enum.to_list(&1.path_info))
  end

  def reset do
    Agent.update(__MODULE__, fn _ -> init_state() end)
  end

  # stat is a map %{mtime: <int>, size: <int>}
  def update_stat(path, stat) do
    update_k_v(path, :stat, stat)
  end

  # used_by is a list of paths that depend on the path
  def update_used_by(path, used_by_list) do
    update_k_v(path, :used_by, used_by_list)
  end

  def add_used_by(path, used_by) do
    Agent.update(__MODULE__, fn state ->
      default = %{stat: nil, used_by: []}
      update_in(state, [:path_info, Access.key(path, default), :used_by], &[used_by | &1])
    end)
  end

  def put_ast(path, ast) do
    Agent.update(__MODULE__, fn state ->
      put_in(state, [:ast, path], ast)
    end)
  end

  def get_ast(path) do
    Agent.get(__MODULE__, & &1.ast[path])
  end

  defp update_k_v(path, k, v) do
    Agent.update(__MODULE__, fn state ->
      default = Map.merge(%{stat: nil, used_by: []}, %{k => v})

      update_in(state, [:path_info, path], fn
        nil -> default
        info -> Map.put(info, k, v)
      end)
    end)
  end

  defp init_state do
    %{
      path_info: %{},
      ast: %{}
    }
  end
end
