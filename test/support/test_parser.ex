defmodule TestParser do
  import NimbleParsec

  alias Fika.Parser.{
    Common,
    Types,
    Expressions,
    FunctionDef,
    UseModule
  }

  exp = parsec({Expressions, :exp})
  function_defs = parsec({FunctionDef, :function_defs})
  use_modules = parsec({UseModule, :use_modules})
  allow_space = parsec({Common, :allow_space})
  parse_type = parsec({Types, :parse_type})

  def expression!(str) do
    {:ok, [result], _rest, _context, _line, _byte_offset} = expression(str)
    result
  end

  defparsec :expression, exp |> concat(allow_space) |> eos()
  defparsec :function_defs, function_defs |> concat(allow_space) |> eos()
  defparsec :type_str, parse_type |> concat(allow_space) |> eos()
  defparsec :use_modules, use_modules |> concat(allow_space) |> eos()
end
