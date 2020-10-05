defmodule Fika.Parser.Term do
  import NimbleParsec

  defparsec :exp, parsec({Fika.Parser.Expression, :exp})
  defparsec :exps, parsec({Fika.Parser.Expression, :exps})
  defparsec :call_args, parsec({Fika.Parser.Function, :call_args})
  defparsec :type, parsec({Fika.Parser.Type, :type})
  defparsec :type_args_list, parsec({Fika.Parser.Type, :type_args_list})

  defcombinator :term, Fika.Lexer.Expression.term()
end
