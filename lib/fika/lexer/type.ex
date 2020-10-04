defmodule Fika.Lexer.Type do
  import NimbleParsec
  alias Fika.ParserHelper, as: Helper

  alias Fika.Lexer.Lexemes, as: LX

  alias LX.{Identifier, Atom}

  defp simple_type do
    ascii_string([?A..?Z], 1)
    |> ascii_string([?a..?z, ?A..?Z], min: 0)
    |> reduce({Enum, :join, [""]})
    |> Helper.to_ast(:simple_type)
  end

  def type_args do
    optional(
      LX.allow_space()
      |> LX.comma()
      |> concat(LX.allow_space())
      |> parsec(:type)
      |> parsec(:type_args)
    )
  end

  def type_args_list do
    optional(
      LX.allow_space()
      |> ignore(LX.comma())
      |> concat(LX.allow_space())
      |> parsec(:type)
      |> parsec(:type_args_list)
    )
  end

  defp type_parens do
    LX.l_paren()
    |> concat(LX.allow_space())
    |> parsec(:type)
    |> concat(type_args())
    |> concat(LX.allow_space())
    |> LX.r_paren()
  end

  # To parse functions with tuple return type
  defp type_tuple_element do
    LX.allow_space()
    |> parsec(:type)
    |> label("tuple element")
  end

  defp type_tuple_elements do
    type_tuple_element()
    |> repeat(
      LX.allow_space()
      |> ignore(LX.comma())
      |> concat(LX.allow_space())
      |> concat(type_tuple_element())
    )
    |> reduce({Enum, :join, [","]})
  end

  defp tuple_type do
    LX.l_curly()
    |> concat(type_tuple_elements())
    |> LX.r_curly()
    |> reduce({Enum, :join, []})
    |> label("tuple type")
  end

  defp type_key_value do
    LX.allow_space()
    |> concat(Identifier.identifier_str())
    |> concat(LX.allow_space())
    |> string(":")
    |> concat(LX.allow_space())
    |> parsec(:type)
    |> label("key value pair")
    |> reduce({Enum, :join, []})
  end

  defp type_key_values do
    type_key_value()
    |> repeat(
      LX.allow_space()
      |> ignore(LX.comma())
      |> concat(LX.allow_space())
      |> concat(type_key_value())
    )
    |> reduce({Enum, :join, [","]})
  end

  defp record_type do
    LX.l_curly()
    |> concat(type_key_values())
    |> LX.r_curly()
    |> reduce({Enum, :join, []})
    |> label("record type")
  end

  defp function_type do
    string("Fn")
    |> LX.l_paren()
    |> optional(parsec(:type) |> concat(type_args()))
    |> concat(LX.allow_space())
    |> string("->")
    |> concat(LX.allow_space())
    |> parsec(:type)
    |> LX.r_paren()
  end

  def type do
    choice([
      function_type(),
      simple_type()
      |> optional(type_parens()),
      record_type(),
      Atom.atom(),
      record_type(),
      tuple_type()
    ])
  end

  def parse_type, do: Helper.to_ast(type(), :type)
end
