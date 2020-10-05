defmodule Fika.Helpers.ParserTest do
  import NimbleParsec
  import Fika.Parser.Delegate

  alias Fika.Lexer.Lexemes, as: LX

  alias Fika.Lexer.{
    Expression,
    Function,
    Type
  }

  # For testing
  def expression!(str) do
    {:ok, [result], _rest, _context, _line, _byte_offset} = expression(str)
    result
  end

  defparsec :expression, Expression.exp() |> concat(LX.allow_space()) |> eos()
  defparsec :function_def, Function.function_def()
  defparsec :type_str, Type.parse_type() |> concat(LX.allow_space()) |> eos()
end
