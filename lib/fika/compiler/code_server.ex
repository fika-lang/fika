defmodule Fika.Compiler.CodeServer do
  use GenServer

  require Logger

  alias Fika.Compiler.{
    DefaultTypes,
    ModuleCompiler,
    ErlTranslate,
    TypeChecker
  }

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def compile_module(module) do
    GenServer.call(__MODULE__, {:compile_module, module})
  end

  def get_type(signature) do
    GenServer.call(__MODULE__, {:get_type, signature})
  end

  def set_type(signature, result) do
    GenServer.cast(__MODULE__, {:set_type, signature, result})
  end

  def put_binary(module, file, binary) do
    GenServer.cast(__MODULE__, {:put_binary, module, file, binary})
  end

  def put_result(module, result) do
    GenServer.cast(__MODULE__, {:put_result, module, result})
  end

  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  # Loads the accumulated binaries which were collected as a result of
  # parallel ModuleCompiler.compile.
  # Returns the list [{:ok, <module>}, {:error, <module>, <reason>}, ...]
  def load_binaries do
    GenServer.call(__MODULE__, :load_binaries)
  end

  def write_binaries(dest) do
    GenServer.call(__MODULE__, {:write_binaries, dest})
  end

  def init(_) do
    state = init_state()

    Logger.debug("Initializing CodeServer")

    {:ok, state}
  end

  def handle_cast({:set_type, signature, result}, state) do
    Logger.debug(
      "Setting typecheck result of public function: #{signature} as #{inspect(result)}"
    )

    state =
      state
      |> set_type(signature, result)
      |> notify_waiting_type_checks(signature.module, signature, result)

    {:noreply, state}
  end

  def handle_cast({:put_result, module, {:error, reason}}, state) do
    Logger.debug("Compilation failed for #{module}")
    state = put_in(state, [:compile_result, module], {:error, reason})
    state = fail_waiting_type_checks(state, module, "Compilation failed for module #{module}")
    maybe_reply_with_result(state.compile_result, state.parent_pid)
    {:noreply, state}
  end

  def handle_cast({:put_result, module, {:ok, {file, binary}}}, state) do
    Logger.debug("Storing binary for #{module}")

    state =
      state
      |> Map.put(:binaries, [{module, file, binary} | state.binaries])
      |> put_in([:compile_result, module], :ok)

    state =
      fail_waiting_type_checks(
        state,
        module,
        "#{module} was compiled, but type was not resolved yet."
      )

    maybe_reply_with_result(state.compile_result, state.parent_pid)
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

  def handle_call({:get_type, signature}, from, state) do
    module = signature.module
    function = signature.function
    signature_map = get_in(state, [:public_functions, module, function])

    state =
      case TypeChecker.find_by_call(signature_map, signature) do
        {_, result} ->
          GenServer.reply(from, result)
          state

        _ ->
          state
          |> async_compile(module)
          # TODO: Check match when notifying waiting type checks.
          |> wait_for(module, signature, from)
      end

    {:noreply, state}
  end

  def handle_call({:compile_module, module}, from, _state) do
    state =
      init_state()
      |> start_module_compile(module)
      |> Map.put(:parent_pid, from)

    {:noreply, state}
  end

  def handle_call(:load_binaries, _from, state) do
    Logger.debug("Loading binaries into beam")

    result =
      Enum.map(state.binaries, fn {module, file, binary} ->
        module_name = ErlTranslate.erl_module_name(module)

        case :code.load_binary(module_name, String.to_charlist(file), binary) do
          {:module, module} -> {:ok, module}
          {:error, _reason} -> {:error, module}
        end
      end)

    {:reply, result, reset_binaries(state)}
  end

  def handle_call({:write_binaries, dest}, _from, state) do
    Logger.debug("Writing binaries to beam files")

    result =
      Enum.map(state.binaries, fn {module, _file, binary} ->
        full_path = Path.join(dest, beam_filename(module))
        File.write!(full_path, binary)
        module
      end)

    {:reply, result, reset_binaries(state)}
  end

  defp beam_filename(module) do
    module
    |> ErlTranslate.erl_module_name()
    |> to_string()
    |> Kernel.<>(".beam")
  end

  defp set_type(state, signature, result) do
    nested_put(state, [:public_functions, signature.module, signature.function, signature], result)
  end

  defp nested_put(map, keys, value) do
    put_in(map, Enum.map(keys, &Access.key(&1, %{})), value)
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

  defp fail_waiting_type_checks(state, module, reason) do
    {waitlist, rest} =
      Enum.reduce(state.waiting, {[], []}, fn {{waited_module, _}, waitlist} = k_v,
                                              {from_acc, rest} ->
        if waited_module == module do
          {waitlist ++ from_acc, rest}
        else
          {from_acc, [k_v | rest]}
        end
      end)

    Enum.each(waitlist, fn from ->
      GenServer.reply(from, {:error, reason})
    end)

    Map.put(state, :waiting, Map.new(rest))
  end

  defp async_compile(state, module) do
    state
    |> start_module_compile(module)
    |> nested_put([:public_functions, module], %{})
  end

  defp wait_for(state, module, signature, from) do
    update_in(state, [:waiting, {module, signature}], fn
      nil -> [from]
      list -> [from | list]
    end)
  end

  defp init_state do
    %{
      public_functions: %{},
      waiting: %{},
      compile_result: %{},
      parent_pid: nil,
      binaries: []
    }
    |> put_default_types(DefaultTypes.kernel())
    |> put_default_types(DefaultTypes.io())
  end

  defp reset_binaries(state) do
    Map.put(state, :binaries, [])
  end

  defp put_default_types(state, signatures) do
    Enum.reduce(signatures, state, fn s, acc ->
      set_type(acc, s, {:ok, s.return})
    end)
  end

  defp start_module_compile(state, module) do
    Task.start(fn ->
      ModuleCompiler.compile(module)
    end)

    put_in(state, [:compile_result, module], nil)
  end

  # Goes through the map %{<module_name> => :ok | :error} and returns
  # {:ok | :error, [module_compile_result]}
  # module_compile_result is {<module_name>, :ok | {:error, <reason>}
  defp maybe_reply_with_result(compile_result, parent_pid) do
    result =
      Enum.reduce_while(compile_result, {:ok, []}, fn
        {_module, nil}, _ ->
          {:halt, nil}

        {module, :ok}, {status, results} ->
          {:cont, {status, [{module, :ok} | results]}}

        {module, {:error, reason}}, {_, results} ->
          {:cont, {:error, [{module, {:error, reason}} | results]}}
      end)

    if result && parent_pid do
      GenServer.reply(parent_pid, result)
    end
  end
end
