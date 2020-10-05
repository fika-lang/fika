defmodule Fika.Parser.Delegate.Function do
  import NimbleParsec
  defdelegate exp__0(a, b, c, d, e, f), to: Fika.Parser.Delegate
  defdelegate exp_bin_op__0(a, b, c, d, e, f), to: Fika.Parser.Delegate
  defdelegate type__0(a, b, c, d, e, f), to: Fika.Parser.Delegate
  defdelegate type_args__0(a, b, c, d, e, f), to: Fika.Parser.Delegate

  defcombinator :call_args, Fika.Lexer.Function.call_args()
  defcombinator :args, Fika.Lexer.Function.args()
end
