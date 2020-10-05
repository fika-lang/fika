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

  defcombinator :args, parsec({Fika.Parser.Function, :args})
  defcombinator :call_args, parsec({Fika.Parser.Function, :call_args})
  defcombinator :exp, parsec({Fika.Parser.Expression, :exp})
  defcombinator :exps, parsec({Fika.Parser.Expression, :exps})
  defcombinator :exp_bin_op, parsec({Fika.Parser.Expression, :exp_bin_op})
  defcombinator :type, parsec({Fika.Parser.Type, :type})
  defcombinator :type_args, parsec({Fika.Parser.Type, :type_args})
  defcombinator :type_args_list, parsec({Fika.Parser.Type, :type_args_list})
  defcombinator :term, parsec({Fika.Parser.Term, :term})

  defparsec :parse, module
end
