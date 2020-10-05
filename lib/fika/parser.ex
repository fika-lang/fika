defmodule Fika.Parser do
  import NimbleParsec

  alias Fika.Lexer.Lexemes, as: LX

  alias Fika.Lexer.Function

  module =
    Function.function_def()
    |> times(min: 1)
    |> concat(LX.allow_space())
    |> eos()

  def parse_module(str, module_name) do
    {:ok, ast, _, _, _, _} = parse(str)
    {:module, module_name, ast}
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

  defparsec :parse, module
end
