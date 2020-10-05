defmodule Fika.Parser.Expression do
  import NimbleParsec

  defparsec :call_args, parsec({Fika.Parser.Function, :call_args})
  defparsec :type, parsec({Fika.Parser.Type, :type})
  defparsec :type_args_list, parsec({Fika.Parser.Type, :type_args_list})
  defparsec :term, parsec({Fika.Parser.Term, :term})

  defcombinator :exp, Fika.Lexer.Expression.exp()
  defcombinator :exps, Fika.Lexer.Expression.exps()
  defcombinator :exp_bin_op, Fika.Lexer.Expression.exp_bin_op()
end
