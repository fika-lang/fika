defmodule Fika.Parser.Function do
  import NimbleParsec

  defparsec :exp, parsec({Fika.Parser.Expression, :exp})
  defparsec :exp_bin_op, parsec({Fika.Parser.Expression, :exp_bin_op})
  defparsec :type, parsec({Fika.Parser.Type, :type})
  defparsec :type_args, parsec({Fika.Parser.Type, :type_args})

  defcombinator :call_args, Fika.Lexer.Function.call_args()
  defcombinator :args, Fika.Lexer.Function.args()
end
