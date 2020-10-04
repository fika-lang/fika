defmodule Fika.Lexer.Lexemes.Atom do
  @moduledoc """
  Defines identifier lexemes
  """

  import NimbleParsec
  alias Fika.ParserHelper, as: Helper

  alias Fika.Lexer.Lexemes.Identifier

  def atom do
    ignore(string(":"))
    |> concat(Identifier.identifier())
    |> label("atom")
    |> Helper.to_ast(:atom)
  end

  def boolean do
    choice([
      string("true"),
      string("false")
    ])
    |> label("boolean")
    |> Helper.to_ast(:boolean)
  end
end
