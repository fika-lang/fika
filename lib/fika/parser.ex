defmodule Fika.Parser do
  import NimbleParsec

  alias Fika.ParserHelper, as: Helper

  horizontal_space =
    choice([
      string("\s"),
      string("\t")
    ])

  vertical_space =
    choice([
      string("\r"),
      string("\n")
    ])

  space =
    choice([vertical_space, horizontal_space])
    |> label("space or newline")

  allow_space =
    space
    |> repeat()
    |> ignore()

  integer =
    integer(min: 1)
    |> label("integer")
    |> Helper.to_ast(:integer)

  exp =
    integer

  # For testing
  defparsec :expression, exp |> concat(allow_space) |> eos()
end
