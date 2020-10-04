defmodule Fika.Lexer.Lexemes.Record do
  @moduledoc """
  Defines identifier lexemes
  """

  import NimbleParsec
  alias Fika.ParserHelper, as: Helper

  alias Fika.Lexer.Lexemes, as: LX
  alias Fika.Lexer.Lexemes.Identifier

  def record do
    wrap(optional(string("Foo")))
    |> ignore(LX.l_curly())
    |> concat(key_value())
    |> repeat(
      LX.allow_space()
      |> ignore(LX.comma())
      |> concat(LX.allow_space())
      |> concat(key_value())
    )
    |> optional(ignore(LX.comma()))
    |> ignore(LX.r_curly())
    |> label("record")
    |> Helper.to_ast(:record)
  end

   defp key_value do
    LX.allow_space()
    |> concat(Identifier.identifier())
    |> concat(LX.allow_space())
    |> ignore(string(":"))
    |> concat(LX.allow_space())
    |> parsec(:exp)
    |> label("key value pair")
    |> Helper.to_ast(:key_value)
  end
end
