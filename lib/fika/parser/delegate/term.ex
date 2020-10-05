defmodule Fika.Parser.Delegate.Term do
  import NimbleParsec

  defdelegate exp__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Expression
  defdelegate exps__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Expression
  defdelegate call_args__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Function
  defdelegate type__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Type
  defdelegate type_args_list__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Type

  defcombinator :term, Fika.Lexer.Expression.term()
end
