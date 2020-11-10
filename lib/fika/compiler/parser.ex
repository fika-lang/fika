defmodule Fika.Compiler.Parser do
  import NimbleParsec

  alias Fika.Compiler.Parser.{
    Common,
    FunctionDef,
    UseModule
  }

  allow_space = parsec({Common, :allow_space})
  function_defs = parsec({FunctionDef, :function_defs})
  use_modules = parsec({UseModule, :use_modules})

  module =
    tag(use_modules, :use_modules)
    |> tag(function_defs, :function_defs)
    |> concat(allow_space)
    |> eos()

  def parse_module(str) do
    case parse(str) do
      {:ok, ast, _, _, _, _} ->
        {:ok, ast}

      {:error, message, _, %{}, {line, offset}, column} ->
        {:error, {line, offset, column}, message}
    end
  end

  defparsec :parse, module
end
