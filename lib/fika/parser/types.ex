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

  comma_separated_types =
    parsec(:type)
    |> repeat(
      allow_space
      |> ignore(string(","))
      |> concat(allow_space)
      |> concat(parsec(:type))
    )
    |> reduce({Enum, :join, [","]})

  tuple_type =
    string("{")
    |> concat(comma_separated_types)
    |> string("}")
    |> reduce({Enum, :join, []})
    |> label("tuple type")

  list_type =
    ignore(string("List("))
    |> concat(parsec(:type))
    |> ignore(string(")"))
    |> label("list type")
    |> Helper.to_ast(:list_type)

  string_type =
    string("String")
    |> label("string")
    |> reduce({Helper, :to_atom, []})

  int_type =
    string("Int")
    |> label("int")
    |> reduce({Helper, :to_atom, []})

  float_type =
    string("Float")
    |> label("float")
    |> reduce({Helper, :to_atom, []})

  nothing_type =
    string("Nothing")
    |> label("nothing")
    |> reduce({Helper, :to_atom, []})

  function_type =
    ignore(string("Fn"))
    |> concat(allow_space)
    |> ignore(string("("))
    |> concat(allow_space)
    |> concat(comma_separated_types)
    |> concat(allow_space)
    |> ignore(string("->"))
    |> concat(parsec(:type))
    |> ignore(string(")"))
    |> label("function def")

  type =
    choice([
      string_type,
      int_type,
      float_type,
      nothing_type,
      atom,
      function_type,
      list_type,
      record_type,
      tuple_type
    ])

  parse_type =
    type
    |> Helper.to_ast(:type)

  defcombinatorp :type_args, type_args
  defcombinator :type, type
  defcombinator :parse_type, parse_type
end
