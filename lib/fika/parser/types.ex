defmodule Fika.Parser.Types do
  import NimbleParsec

  alias Fika.Parser.{Common, Helper}

  allow_space = parsec({Common, :allow_space})
  identifier_str = parsec({Common, :identifier_str})
  atom = parsec({Common, :atom})

  type_args =
    optional(
      allow_space
      |> string(",")
      |> concat(allow_space)
      |> parsec(:type)
      |> parsec(:type_args)
    )

  function_type =
    string("Fn")
    |> string("(")
    |> optional(parsec(:type) |> concat(type_args))
    |> concat(allow_space)
    |> string("->")
    |> concat(allow_space)
    |> parsec(:type)
    |> string(")")

  simple_type =
    ascii_string([?A..?Z], 1)
    |> ascii_string([?a..?z, ?A..?Z], min: 0)
    |> reduce({Enum, :join, [""]})
    |> Helper.to_ast(:simple_type)

  type_parens =
    string("(")
    |> concat(allow_space)
    |> parsec(:type)
    |> concat(type_args)
    |> concat(allow_space)
    |> string(")")

  type_key_value =
    allow_space
    |> concat(identifier_str)
    |> concat(allow_space)
    |> string(":")
    |> concat(allow_space)
    |> parsec(:type)
    |> label("key value pair")
    |> reduce({Enum, :join, []})

  type_key_values =
    type_key_value
    |> repeat(
      allow_space
      |> ignore(string(","))
      |> concat(allow_space)
      |> concat(type_key_value)
    )
    |> reduce({Enum, :join, [","]})

  record_type =
    string("{")
    |> concat(type_key_values)
    |> string("}")
    |> reduce({Enum, :join, []})
    |> label("record type")

  # To parse functions with map return type
  type_map_key_value =
    allow_space
    |> parsec(:type)
    |> string(",")
    |> concat(allow_space)
    |> parsec(:type)
    |> concat(allow_space)

  map_type =
    string("Map(")
    |> concat(type_map_key_value)
    |> string(")")
    |> label("map type")

  # To parse functions with tuple return type
  type_tuple_element =
    parsec(:type)
    |> label("tuple element")

  type_tuple_elements =
    type_tuple_element
    |> repeat(
      allow_space
      |> ignore(string(","))
      |> concat(allow_space)
      |> concat(type_tuple_element)
    )
    |> reduce({Enum, :join, [","]})

  tuple_type =
    string("{")
    |> concat(type_tuple_elements)
    |> string("}")
    |> reduce({Enum, :join, []})
    |> label("tuple type")

  type =
    choice([
      function_type,
      simple_type
      |> optional(type_parens),
      atom,
      record_type,
      map_type,
      tuple_type
    ])

  parse_type =
    type
    |> Helper.to_ast(:type)

  defcombinatorp :type_args, type_args
  defcombinator :type, type
  defcombinator :parse_type, parse_type
end
