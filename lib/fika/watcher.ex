defmodule Fika.Watcher do
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    dir = File.cwd!()

    case FileSystem.start_link(dirs: [dir]) do
      {:ok, watcher_pid} ->
        Logger.debug("Initializing Watcher")
        FileSystem.subscribe(watcher_pid)

        state = %{
          watcher_pid: watcher_pid,
          paths: MapSet.new(),
          timer: nil
        }

        {:ok, state}

      _other ->
        Logger.error("Watcher disabled.")
        :ignore
    end
  end

  def handle_info({:file_event, _watcher_pid, {path, _events}}, state) do
    relative_path = Path.relative_to_cwd(path)

    state =
      if String.ends_with?(relative_path, ".fi") do
        state
        |> Map.put(:paths, MapSet.put(state.paths, relative_path))
        |> Map.put(:timer, reset_timer(state.timer))
      else
        state
      end

    {:noreply, state}
  end

  def handle_info(:trigger, %{paths: paths} = state) do
    Logger.debug("Files changed: #{inspect(paths)}")

    router = Application.get_env(:fika, :router_path)

    if router in paths do
      Fika.Router.Store.reload_routes(router)
    end

    {:noreply, %{state | paths: MapSet.new(), timer: nil}}
  end

  # Depending on FS backends and code editors, we may get multiple file_event
  # messages for a single change in a file. To combine these into a single
  # change, we accumulate events which are triggered <100ms apart, group
  # them together and send a single :trigger event.
  defp reset_timer(timer) do
    if timer do
      Process.cancel_timer(timer)
    end

    Process.send_after(self(), :trigger, 100)
  end
end
