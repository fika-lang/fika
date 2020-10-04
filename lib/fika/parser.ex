defmodule Fika.Parser do
  import NimbleParsec

  alias Fika.Lexer.Lexemes, as: LX

  alias Fika.Lexer.{
    Expression,
    Function,
    Type
  }

  module =
    Function.function_def()
    |> times(min: 1)
    |> concat(LX.allow_space())
    |> eos()

  def parse_module(str, module_name) do
    {:ok, ast, _, _, _, _} = parse(str)
    {:module, module_name, ast}
  end

  def expression!(str) do
    {:ok, [result], _rest, _context, _line, _byte_offset} = expression(str)
    result
  end

  defcombinatorp :exp, Expression.exp()
  defcombinatorp :exps, Expression.exps()
  defcombinatorp :exp_bin_op, Expression.exp_bin_op()
  defcombinatorp :term, Expression.term()
  defcombinatorp :args, Function.args()
  defcombinatorp :call_args, Function.call_args()
  defcombinatorp :type, Type.type()
  defcombinatorp :type_args, Type.type_args()
  defcombinatorp :type_args_list, Type.type_args_list()

  defparsec :parse, module

  # For testing
  defparsec :expression, Expression.exp() |> concat(LX.allow_space()) |> eos()
  defparsec :function_def, Function.function_def()
  defparsec :type_str, Type.parse_type() |> concat(LX.allow_space()) |> eos()
end
