defmodule Fika.Parser do
  import NimbleParsec
  import Fika.Parser.Delegate

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

  defparsec :parse, module
end
