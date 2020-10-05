defmodule Fika.Helpers.TestParser do
  import NimbleParsec

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

  defcombinatorp :args, parsec({Fika.Parser, :args})
  defcombinatorp :call_args, parsec({Fika.Parser, :call_args})
  defcombinatorp :exp, parsec({Fika.Parser, :exp})
  defcombinatorp :exps, parsec({Fika.Parser, :exps})
  defcombinatorp :exp_bin_op, parsec({Fika.Parser, :exp_bin_op})
  defcombinatorp :type, parsec({Fika.Parser, :type})
  defcombinatorp :type_args, parsec({Fika.Parser, :type_args})
  defcombinatorp :type_args_list, parsec({Fika.Parser, :type_args_list})
  defcombinatorp :term, parsec({Fika.Parser, :term})

  defparsec :expression, Expression.exp() |> concat(LX.allow_space()) |> eos()
  defparsec :function_def, Function.function_def()
  defparsec :type_str, Type.parse_type() |> concat(LX.allow_space()) |> eos()
end
