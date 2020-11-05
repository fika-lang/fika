defmodule Fika.Compiler.ModuleCompiler do
  require Logger

  alias Fika.{
    Compiler.Parser,
    Compiler.TypeChecker.ParallelTypeChecker,
    Compiler.ErlTranslate,
    CodeServer
  }

  # Returns {:ok, module_name, file, binary} | {:error, message}
  def compile(module_name, manager_pid \\ nil) do
    Logger.debug("Compiling #{module_name}")
    state = init(module_name, manager_pid)

    with {:ok, str} <- read_file(state.file),
         {:ok, state} <- parse(str, state),
         :ok <- type_check(state),
         {:ok, forms} <- erl_translate(state) do
      compile_forms(forms, state)
    end
  end

  defp init(module_atom, manager_pid) do
    %{
      # Full name of the current module as atom
      module_name: module_atom,
      # PID of manager process
      manager_pid: manager_pid,
      # Path of module file
      file: "#{module_atom}.fi",
      # AST which will be created by parser
      ast: nil
    }
  end

  def read_file(file) do
    case File.read(file) do
      {:error, error} ->
        {:error, "Cannot read file #{file}: #{inspect(error)}"}

      {:ok, str} ->
        {:ok, str}
    end
  end

  defp parse(str, state) do
    case Parser.parse_module(str) do
      {:ok, ast} ->
        {:ok, Map.put(state, :ast, ast)}

      {:error, {line, _offset, _column}, message} ->
        message = """
        Parse error: #{state.file}:#{line}
        #{inspect(message)}
        """

        {:error, message}
    end
  end

  defp type_check(state) do
    ParallelTypeChecker.check(state.module_name, state.ast[:function_defs])
  end

  defp erl_translate(state) do
    forms = ErlTranslate.translate(state.ast, state.module_name, state.file)
    {:ok, forms}
  end

  defp compile_forms(forms, state) do
    case :compile.forms(forms) do
      {:ok, _, binary} ->
        CodeServer.put_binary(state.module_name, state.file, binary)
        {:ok, state.module_name, state.file, binary}

      {:error, errors, warnings} ->
        message = """
        Error while compiling Erlang forms: #{state.file}
        Errors: #{inspect(errors)}
        Warnings: #{inspect(warnings)}
        """

        {:error, message}
    end
  end
end
