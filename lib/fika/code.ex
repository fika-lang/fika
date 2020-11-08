defmodule Fika.Code do
  alias Fika.CodeServer

  # Returns one of the following:
  # {:error, [{:error, module}, {:ok, module}, ...]} if compilation fails
  # for at least one module
  #
  # {:ok, [{:error, module}, {:ok, module}, ...]} if compilation succeeds and loading
  # has finished. If a module failed to load, it will be present in the list as
  # {:error, module}. {:ok, module} if the module was successfully loaded.
  def load_module(module_name_str) do
    CodeServer.reset()
    module = String.to_atom(module_name_str)

    case CodeServer.compile_module(module) do
      {:ok, _} ->
        {:ok, CodeServer.load()}

      error ->
        error
    end
  end
end
