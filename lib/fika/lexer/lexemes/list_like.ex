defmodule Fika.Lexer.Lexemes.ListLike do
  @moduledoc """
  Defines identifier lexemes
  """

  import NimbleParsec

  alias Fika.ParserHelper, as: Helper

  alias Fika.Lexer.Lexemes, as: LX

  def list do
    ignore(LX.l_bracket())
    |> concat(LX.allow_space())
    |> optional(list_content())
    |> concat(LX.allow_space())
    |> ignore(LX.r_bracket())
    |> Helper.to_ast(:exp_list)
  end

  def tuple do
    ignore(LX.l_curly())
    |> concat(LX.allow_space())
    |> concat(list_content())
    |> concat(LX.allow_space())
    |> ignore(LX.r_curly())
    |> Helper.to_ast(:tuple)
  end

  defp list_rest do
    ignore(LX.comma())
    |> concat(LX.allow_space())
    |> parsec(:exp)
  end

  defp list_content do
    parsec(:exp)
    |> concat(LX.allow_space())
    |> repeat(list_rest())
  end
end
