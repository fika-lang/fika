defmodule Fika.Lexer.If do
  @moduledoc """
  Defines identifier lexemes
  """

  import NimbleParsec
  alias Fika.ParserHelper, as: Helper

  alias Fika.Lexer.Lexemes, as: LX

  def if do
    ignore(string("if"))
    |> concat(LX.require_space())
    |> parsec(:exp)
    |> concat(LX.require_space())
    |> ignore(string("do"))
    |> concat(LX.require_space())
    |> wrap(parsec(:exps))
    |> concat(LX.require_space())
    |> ignore(string("else"))
    |> concat(LX.require_space())
    |> wrap(parsec(:exps))
    |> concat(LX.require_space())
    |> ignore(string("end"))
    |> label("if-else expression")
    |> Helper.to_ast(:exp_if_else)
  end
end
