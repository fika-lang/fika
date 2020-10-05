defmodule Fika.Parser.Delegate do
  defdelegate args__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Function
  defdelegate call_args__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Function
  defdelegate exp__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Expression
  defdelegate exps__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Expression
  defdelegate exp_bin_op__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Expression
  defdelegate type__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Type
  defdelegate type_args__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Type
  defdelegate type_args_list__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Type
  defdelegate term__0(a, b, c, d, e, f), to: Fika.Parser.Delegate.Term
end
