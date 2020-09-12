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

  exp_paren =
    ignore(string("("))
    |> parsec(:exp)
    |> ignore(string(")"))
    |> label("expression in parentheses")

  factor =
    choice([
      integer,
      exp_paren
    ])

  term =
    factor
    |> optional(
      allow_space
      |> choice([string("*"), string("/")])
      |> concat(allow_space)
      |> parsec(:term)
    )

  exp_mult_op =
    Helper.to_ast(term, :exp_bin_op)

  exp_bin_op =
    exp_mult_op
    |> optional(
      allow_space
      |> choice([string("+"), string("-")])
      |> concat(allow_space)
      |> parsec(:exp_bin_op)
    )

  exp_add_op =
    Helper.to_ast(exp_bin_op, :exp_bin_op)

  exp =
    exp_add_op


  defcombinatorp :exp, exp
  defcombinatorp :exp_bin_op, exp_bin_op
  defcombinatorp :term, term

  # For testing
  defparsec :expression, exp |> concat(allow_space) |> eos()
end
