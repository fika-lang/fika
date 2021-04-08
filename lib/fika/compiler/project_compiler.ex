defmodule Fika.Compiler.ProjectCompiler do
  alias Fika.Compiler.{
    CodeServer,
    Diagnostics,
    PathHelper,
    Parser,
    Cache
  }

  def compile(root) do
    # {to_delete, to_compile} = changeset(root)
    {to_delete, to_add, to_recheck} = changeset(root)

    [
      delete_all(to_delete, root),
      add_all(to_add, root),
      check_all(to_recheck, root)
    ] == [true, true, true]
  end

  def changeset(root) do
    latest_paths = latest_paths(root)
    cached_paths = Cache.all_paths()
    get_changeset(cached_paths, latest_paths, [], [], [])
  end

  def delete_all(paths, root) do
    Enum.each(paths, fn path ->
      path
      |> PathHelper.path_to_module(root)
      |> CodeServer.delete_module()
    end)
  end

  def add_all(paths, root) do
    stream =
      Task.async_stream(paths, fn path ->
        :ok
        # ModuleCompiler.load(path, root)
      end)

    Enum.all?(stream, fn {:ok, result} -> result == :ok end)
  end

  def check_all(paths, root) do
    stream =
      Task.async_stream(paths, fn path ->
        :ok
        # ModuleCompiler.check(path, root)
      end)

    Enum.all?(stream, fn {:ok, result} -> result == :ok end)
  end

  # def parse_all(paths) do
  # stream =
  # Task.async_stream(paths, fn path ->
  # with {:ok, str} <- File.read(path),
  # {:ok, ast} <- Parser.parse_module(str) do
  # {:ok, ast}
  # else
  # {:error, {line, _, _}, message} ->
  # {:error, Diagnostics.parse_error(path, line, message)}

  # {:error, _} ->
  # {:error, Diagnostics.parse_error(path, nil, "Cannot read the file")}
  # end
  # end)

  # Enum.map(stream, fn {:ok, result} -> result end)
  # end

  def latest_paths(root) do
    current_paths = Path.wildcard("#{root}/**/*.fi")

    Enum.map(current_paths, fn path ->
      stat = last_modified_and_size(path)
      {path, stat}
    end)
    |> Map.new()
  end

  def last_modified_and_size(path) do
    now = System.os_time(:second)

    case :elixir_utils.read_posix_mtime_and_size(path) do
      {:ok, mtime, size} when mtime > now ->
        File.touch(path, now)
        {mtime, size}

      {:ok, mtime, size} ->
        {mtime, size}

      {:error, _} ->
        {0, 0}
    end
  end

  defp get_changeset([], latest_paths, to_delete, to_add, to_recheck) do
    paths = Enum.map(latest_paths, fn {m, _} -> m end)

    {
      Enum.uniq(to_delete),
      Enum.uniq(paths ++ to_add),
      Enum.uniq((to_recheck -- to_add) -- to_delete)
    }
  end

  defp get_changeset([c_path | cached_paths], latest_paths, to_delete, to_add, to_recheck) do
    {path, %{stat: c_stat, used_by: used_by_paths}} = c_path

    case Map.pop(latest_paths, path) do
      {nil, _} ->
        to_delete = [path | to_delete]
        to_recheck = used_by_paths ++ to_recheck
        get_changeset(cached_paths, latest_paths, to_delete, to_add, to_recheck)

      {{mtime, size}, latest_paths} ->
        {to_delete, to_add, to_recheck} =
          if size != c_stat[:size] or mtime > c_stat[:mtime] do
            {[path | to_delete], [path | to_add], used_by_paths ++ to_recheck}
          else
            {to_delete, to_add, to_recheck}
          end

        get_changeset(cached_paths, latest_paths, to_delete, to_add, to_recheck)
    end
  end
end
