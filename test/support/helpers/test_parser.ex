defmodule Fika.Helpers.TestParser do
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

  defparsec :args, parsec({Fika.Parser.Function, :args})
  defparsec :call_args, parsec({Fika.Parser.Function, :call_args})
  defparsec :exp, parsec({Fika.Parser.Expression, :exp})
  defparsec :exps, parsec({Fika.Parser.Expression, :exps})
  defparsec :exp_bin_op, parsec({Fika.Parser.Expression, :exp_bin_op})
  defparsec :type, parsec({Fika.Parser.Type, :type})
  defparsec :type_args, parsec({Fika.Parser.Type, :type_args})
  defparsec :type_args_list, parsec({Fika.Parser.Type, :type_args_list})
  defparsec :term, parsec({Fika.Parser.Term, :term})

  defparsec :expression, Expression.exp() |> concat(LX.allow_space()) |> eos()
  defparsec :function_def, Function.function_def()
  defparsec :type_str, Type.parse_type() |> concat(LX.allow_space()) |> eos()
end
