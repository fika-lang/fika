defmodule TestParser do
  import NimbleParsec

  alias Fika.Parser.{
    Common,
    Types,
    Expressions,
    FunctionDef
  }

  exp = parsec({Expressions, :exp})
  exps = parsec({Expressions, :exps})
  function_def = parsec({FunctionDef, :function_def})
  allow_space = parsec({Common, :allow_space})
  parse_type = parsec({Types, :parse_type})

  def expression!(str) do
    {:ok, [result], _rest, _context, _line, _byte_offset} = expression(str)
    result
  end

  defparsec :expression, exp |> concat(allow_space) |> eos()
  defparsec :function_def, function_def

  defparsec :type_str,
            parse_type
            |> concat(allow_space)
            |> eos()

  defparsec :exps, exps |> concat(allow_space) |> eos()
end
