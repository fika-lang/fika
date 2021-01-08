defmodule Fika.Compiler.FunctionSignature do
  defstruct [:module, :function, :return, types: []]

  alias Fika.Compiler.TypeChecker.Types, as: T

  defimpl String.Chars, for: __MODULE__ do
    def to_string(%{module: m, function: f, types: ts, return: r}) do
      types_str = T.Helper.join_list(ts)

      str =
        if m do
          "#{m}."
        else
          ""
        end

      str = "#{str}#{f}(#{types_str})"

      if r do
        "#{str} -> #{r}"
      else
        str
      end
    end
  end
end
