defmodule Fika.Compiler.Parser.Pattern do
  import NimbleParsec

  alias Fika.Compiler.Parser.{Common, Helper}

  allow_space = parsec({Common, :allow_space})
  atom_literal = parsec({Common, :atom})
  identifier = parsec({Common, :identifier})

  integer_literal =
    integer(min: 1)
    |> label("integer")
    |> Helper.to_ast(:integer)

  string_literal =
    ignore(string("\""))
    |> repeat(choice([string(~S{\"}), utf8_char(not: ?")]))
    |> ignore(string("\""))
    |> Helper.to_ast(:string)

  list_rest =
    ignore(string(","))
    |> concat(allow_space)
    |> parsec(:pattern)

  list_content =
    parsec(:pattern)
    |> concat(allow_space)
    |> repeat(list_rest)

  tuple =
    ignore(string("{"))
    |> concat(allow_space)
    |> concat(list_content)
    |> concat(allow_space)
    |> ignore(string("}"))
    |> Helper.to_ast(:tuple)

  key_value =
    allow_space
    |> concat(identifier)
    |> concat(allow_space)
    |> ignore(string(":"))
    |> concat(allow_space)
    |> parsec(:pattern)
    |> Helper.to_ast(:key_value)

  record =
    wrap(optional(string("Foo")))
    |> ignore(string("{"))
    |> concat(key_value)
    |> repeat(
      allow_space
      |> ignore(string(","))
      |> concat(allow_space)
      |> concat(key_value)
    )
    |> optional(ignore(string(",")))
    |> ignore(string("}"))
    |> Helper.to_ast(:record)

  pattern =
    choice([
      atom_literal,
      string_literal,
      integer_literal,
      identifier,
      tuple,
      record
    ])

  defcombinator :pattern, pattern
end
