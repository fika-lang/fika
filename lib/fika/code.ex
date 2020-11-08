defmodule Fika.Code do
  alias Fika.CodeServer

  def load_module(module_name_str) do
    CodeServer.reset()
    module = String.to_atom(module_name_str)
    case CodeServer.compile_module(module) do
      {:ok, _} ->
        CodeServer.load()
      error ->
        error
    end
  end
end
