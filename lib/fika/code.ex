defmodule Fika.Code do
  alias Fika.Compiler.CodeServer

  # Returns one of the following:
  # {:error, [{:error, module}, {:ok, module}, ...]} if compilation fails
  # for at least one module
  #
  # {:ok, [{:error, module}, {:ok, module}, ...]} if compilation succeeds and loading
  # has finished. If a module failed to load, it will be present in the list as
  # {:error, module}. {:ok, module} if the module was successfully loaded.
  def load_module(module_name_str) do
    CodeServer.reset()

    case CodeServer.compile_module(module_name_str) do
      {:ok, _} ->
        {:ok, CodeServer.load_binaries()}

      error ->
        error
    end
  end

  def load_file(module, content) do
    case CodeServer.compile_file(module, content) do
      {:ok, _} ->
        {:ok, CodeServer.load_binaries()}

      error ->
        error
    end
  end

  def compile_to_path(module_name_str, dest) do
    CodeServer.reset()

    case CodeServer.compile_module(module_name_str) do
      {:ok, _} ->
        {:ok, CodeServer.write_binaries(dest)}

      error ->
        error
    end
  end
end
