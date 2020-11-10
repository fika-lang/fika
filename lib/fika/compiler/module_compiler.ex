defmodule Fika.Compiler.ModuleCompiler do
  require Logger

  alias Fika.Compiler.{
    Parser,
    TypeChecker.ParallelTypeChecker,
    ErlTranslate,
    CodeServer
  }

  # Returns {:ok, module_name, file, binary} | {:error, message}
  def compile(module_name) do
    Logger.debug("Compiling #{module_name}")

    result = do_compile(module_name)

    case result do
      {:ok, module_name, file, binary} ->
        CodeServer.put_result(module_name, {:ok, {file, binary}})

      {:error, reason} ->
        CodeServer.put_result(module_name, {:error, reason})
    end

    result
  end

  defp do_compile(module_name) do
    state = init(module_name)

    with {:ok, str} <- read_file(state.file),
         {:ok, state} <- parse(str, state),
         :ok <- type_check(state),
         {:ok, forms} <- erl_translate(state) do
      compile_forms(forms, state)
    end
  end

  defp init(module_atom) do
    %{
      # Full name of the current module as atom
      module_name: module_atom,
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
        Logger.debug("File #{file} read successfully")
        {:ok, str}
    end
  end

  defp parse(str, state) do
    case Parser.parse_module(str) do
      {:ok, ast} ->
        Logger.debug("Module #{state.module_name} parsed successfully")
        {:ok, Map.put(state, :ast, ast)}

      {:error, _position, _message} ->
        {:error, "Parse error"}
    end
  end

  defp type_check(state) do
    case ParallelTypeChecker.check(state.module_name, state.ast[:function_defs]) do
      :ok -> :ok
      :error -> {:error, "Type check error"}
    end
  end

  defp erl_translate(state) do
    forms = ErlTranslate.translate(state.ast, state.module_name, state.file)
    {:ok, forms}
  end

  defp compile_forms(forms, state) do
    case :compile.forms(forms) do
      {:ok, _, binary} ->
        {:ok, state.module_name, state.file, binary}

      {:error, _errors, _warnings} ->
        {:error, "Load error"}
    end
  end
end
