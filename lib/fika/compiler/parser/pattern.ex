defmodule Fika.Compiler.Parser.Pattern do
  import NimbleParsec

  # TODO: We need to add other patterns like records and matches.
  # See https://erlang.org/doc/apps/erts/absform.html#patterns
  # Also, we can organize the parser modules better.

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

  pattern =
    choice([
      atom_literal,
      string_literal,
      integer_literal,
      identifier,
      tuple
    ])

  defcombinator :pattern, pattern
end
