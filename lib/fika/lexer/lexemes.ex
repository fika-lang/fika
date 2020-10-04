defmodule Fika.Lexer.Lexemes do
  @moduledoc """
  Defines some basic lexemes which can be used by other `Fika.Lexer` submodules.
  """

  import NimbleParsec

  def comma(), do: string(",")
  def comma(arg), do: string(arg, ",")

  def l_paren(), do: string("(")
  def l_paren(arg), do: string(arg, "(")

  def r_paren(), do: string(")")
  def r_paren(arg), do: string(arg, ")")

  def l_bracket(), do: string("[")

  def r_bracket(), do: string("]")

  def l_curly(), do: string("{")

  def r_curly(), do: string("}")
  def r_curly(arg), do: string(arg, "}")

  def require_space do
    space()
    |> times(min: 1)
    |> ignore()
  end

  def allow_space do
    space()
    |> repeat()
    |> ignore()
  end

  def keyword do
    choice([
      string("fn"),
      string("do"),
      string("end"),
      string("if"),
      string("else")
    ])
  end

  defp horizontal_space do
    choice([
      string("\s"),
      string("\t")
    ])
  end

  defp vertical_space do
    choice([
      string("\r"),
      string("\n")
    ])
  end

  defp comment do
    string("#")
    |> repeat(utf8_char(not: ?\n))
    |> string("\n")
  end

  defp space do
    choice([vertical_space(), horizontal_space(), comment()])
    |> label("space or newline")
  end
end
