defmodule Fika.Parser.Delegate.Expression do
  import NimbleParsec

  defdelegate call_args__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Function
  defdelegate term__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Term
  defdelegate type__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Type
  defdelegate type_args_list__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Type

  defcombinator :exp, Fika.Lexer.Expression.exp()
  defcombinator :exps, Fika.Lexer.Expression.exps()
  defcombinator :exp_bin_op, Fika.Lexer.Expression.exp_bin_op()
end
