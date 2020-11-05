defmodule Fika.CodeServer do
  use GenServer

  require Logger

  alias Fika.Compiler.ModuleCompiler

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get_type(module, signature) do
    GenServer.call(__MODULE__, {:get_result, module, signature})
  end

  def set_type(module, signature, result) do
    GenServer.cast(__MODULE__, {:set_type, module, signature, result})
  end

  def put_binary(module, file, binary) do
    GenServer.cast(__MODULE__, {:put_binary, module, file, binary})
  end

  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  def load do
    GenServer.call(__MODULE__, :load)
  end

  def init(_) do
    state = init_state()

    Logger.debug("Initializing Compiler")

    {:ok, state}
  end

  def handle_cast({:set_type, module, signature, result}, state) do
    Logger.debug(
      "Setting result of public function: #{module}.#{signature} as #{inspect(result)}"
    )

    state =
      state
      |> set_result(module, signature, result)
      |> notify_waiting_type_checks(module, signature, result)

    {:noreply, state}
  end

  def handle_cast({:put_binary, module, file, binary}, state) do
    Logger.debug("Storing binary for #{module}")
    state = %{state | binaries: [{module, file, binary} | state.binaries]}
    {:noreply, state}
  end

  def handle_call(:reset, _from, _state) do
    {:reply, :ok, init_state()}
  end

  def handle_call({:get_result, module, signature}, from, state) do
    state =
      if result = get_in(state, [:public_functions, module, signature]) do
        GenServer.reply(from, result)
        state
      else
        state
        |> maybe_compile(module)
        |> wait_for(module, signature, from)
      end

    {:noreply, state}
  end

  def handle_call(:load, _from, state) do
    result =
      Enum.map(state.binaries, fn {module, file, binary} ->
        case :code.load_binary(module, String.to_charlist(file), binary) do
          {:module, module} -> {:ok, module}
          {:error, reason} -> {:error, module, reason}
        end
      end)

    {:reply, result, state}
  end

  defp set_result(state, module, signature, result) do
    update_in(state, [:public_functions, module], fn
      nil -> %{signature => result}
      signatures -> Map.put(signatures, signature, result)
    end)
  end

  defp notify_waiting_type_checks(state, module, signature, result) do
    {waitlist, waiting} = Map.pop(state.waiting, {module, signature})

    if waitlist do
      Enum.each(waitlist, fn from ->
        GenServer.reply(from, result)
      end)
    end

    Map.put(state, :waiting, waiting)
  end

  defp maybe_compile(state, module) do
    update_in(state, [:public_functions, module], fn
      nil ->
        Task.start(fn ->
          ModuleCompiler.compile(module)
        end)

        %{}

      other ->
        other
    end)
  end

  defp wait_for(state, module, signature, from) do
    update_in(state, [:waiting, {module, signature}], fn
      nil -> [from]
      list -> [from | list]
    end)
  end

  defp init_state do
    %{
      public_functions: default_functions(),
      waiting: %{},
      binaries: []
    }
  end

  defp default_functions do
    %{
      kernel: insert_ok(Fika.Kernel.types())
    }
  end

  defp insert_ok(signature_map) do
    Enum.map(signature_map, fn {k, v} ->
      {k, {:ok, v}}
    end) |> Map.new()
  end
end
