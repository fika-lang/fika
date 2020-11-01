defmodule Fika.Parser.Types do
  import NimbleParsec

  alias Fika.Parser.{Common, Helper}

  allow_space = parsec({Common, :allow_space})
  identifier_str = parsec({Common, :identifier_str})
  atom = parsec({Common, :atom})

  atom_type = Helper.to_ast(atom, :atom_type)

  type_args =
    parsec(:type)
    |> optional(
      allow_space
      |> ignore(string(","))
      |> concat(allow_space)
      |> parsec(:type_args)
    )

  function_type =
    ignore(string("Fn("))
    |> optional(type_args |> map({Helper, :tag, [:arg_type]}))
    |> concat(allow_space)
    |> ignore(string("->"))
    |> concat(allow_space)
    |> concat(
      parsec(:type)
      |> map({Helper, :tag, [:return_type]})
    )
    |> ignore(string(")"))
    |> Helper.to_ast(:function_type)

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
  map_type =
    string("Map")
    |> string("(")
    |> parsec(:type)
    |> concat(allow_space)
    |> string(",")
    |> concat(allow_space)
    |> parsec(:type)
    |> concat(allow_space)
    |> string(")")
    |> label("map type")

  tuple_type =
    ignore(string("{"))
    |> concat(type_args)
    |> ignore(string("}"))
    |> label("tuple type")
    |> Helper.to_ast(:tuple_type)

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

  base_type =
    choice([
      list_type,
      record_type,
      map_type,
      tuple_type,
      function_type,
      string_type,
      int_type,
      float_type,
      nothing_type,
      atom_type
    ])

  union_type =
    base_type
    |> times(
      allow_space
      |> ignore(string("|"))
      |> concat(allow_space)
      |> concat(base_type),
      min: 1
    )
    |> label("union type")
    |> Helper.to_ast(:union_type)

  type = choice([union_type, base_type])

  parse_type =
    type
    |> Helper.to_ast(:type)

  defcombinatorp :type_args, type_args
  defcombinator :type, type
  defcombinator :parse_type, parse_type
end
