defmodule Fika.Lexer.Lexemes.Identifier do
  @moduledoc """
  Defines identifier lexemes
  """

  import NimbleParsec
  alias Fika.ParserHelper, as: Helper

  alias Fika.Lexer.Lexemes, as: LX

  def identifier do
    lookahead_not(LX.keyword())
    |> concat(identifier_str())
    |> label("identifier")
    |> Helper.to_ast(:identifier)
  end

  def identifier_str do
    ascii_string([?a..?z], 1)
    |> ascii_string([?a..?z, ?_, ?0..?9], min: 0)
    |> reduce({Enum, :join, [""]})
    |> label("snake_case string")
  end
end
