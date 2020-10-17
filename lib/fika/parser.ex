defmodule Fika.Parser do
  import NimbleParsec

  alias Fika.Parser.{
    Common,
    FunctionDef,
    UseModule
  }

  allow_space = parsec({Common, :allow_space})
  function_defs = parsec({FunctionDef, :function_defs})
  use_modules = parsec({UseModule, :use_modules})

  module =
    optional(use_modules)
    |> concat(function_defs)
    |> concat(allow_space)
    |> eos()

  def parse_module(str, module_name) do
    {:ok, ast, _, _, _, _} = parse(str)
    {:module, module_name, Map.new(ast)}
  end

  defparsec :parse, module
end
