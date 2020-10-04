defmodule Fika.Lexer.Lexemes.String do
  @moduledoc """
  Defines identifier lexemes
  """

  import NimbleParsec
  alias Fika.ParserHelper, as: Helper

  def string do
    ignore(string("\""))
    |> repeat(choice([string("\\\""), utf8_char(not: ?")]))
    |> ignore(string("\""))
    |> Helper.to_ast(:string)
  end
end
