defmodule Fika.Parser do
  import NimbleParsec

  alias Fika.Parser.{
    FunctionDef,
    Common
  }

  allow_space = parsec({Common, :allow_space})
  function_def = parsec({FunctionDef, :function_def})

  module =
    function_def
    |> times(min: 1)
    |> concat(allow_space)
    |> eos()

  def parse_module(str, module_name) do
    {:ok, ast, _, _, _, _} = parse(str)
    {:module, module_name, ast}
  end

  defparsec :parse, module
end
