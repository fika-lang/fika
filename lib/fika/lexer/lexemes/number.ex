defmodule Fika.Lexer.Lexemes.Number do
  @moduledoc """
  Defines identifier lexemes
  """

  import NimbleParsec
  alias Fika.ParserHelper, as: Helper

  def integer do
    integer(min: 1)
    |> label("integer")
    |> Helper.to_ast(:integer)
  end
end
