defmodule Fika.Parser.Expressions do
  import NimbleParsec

  alias Fika.Parser.{Common, Helper, LiteralExps, NonLiteralExps}

  allow_space = parsec({Common, :allow_space})
  allow_horizontal_space = parsec({Common, :allow_horizontal_space})
  identifier = parsec({Common, :identifier})
  literal_exps = parsec({LiteralExps, :literal_exps})
  non_literal_exps = parsec({NonLiteralExps, :non_literal_exps})

  exp_match =
    identifier
    |> concat(allow_horizontal_space)
    |> ignore(string("="))
    |> concat(allow_space)
    |> parsec(:exp)
    |> label("match expression")
    |> Helper.to_ast(:exp_match)

  factor =
    choice([
      literal_exps,
      non_literal_exps
    ])

  term =
    factor
    |> optional(
      allow_horizontal_space
      |> choice([string("*"), string("/"), string("&")])
      |> concat(allow_space)
      |> parsec(:term)
    )

  exp_mult_op = Helper.to_ast(term, :exp_bin_op)

  exp_bin_op =
    exp_mult_op
    |> optional(
      allow_horizontal_space
      |> choice([string("+"), string("-"), string("|")])
      |> concat(allow_space)
      |> parsec(:exp_bin_op)
    )

  exp_add_op = Helper.to_ast(exp_bin_op, :exp_bin_op)

  exp =
    choice([
      exp_match,
      exp_add_op
    ])
    |> label("expression")

  exp_delimiter =
    allow_horizontal_space
    |> ignore(times(choice([string("\n"), string(";")]), min: 1))
    |> concat(allow_horizontal_space)

  exps =
    parsec(:exp)
    |> optional(
      exp_delimiter
      |> parsec(:exps)
    )

  defcombinatorp :exp_bin_op, exp_bin_op
  defcombinatorp :term, term
  defcombinator :exp, exp
  defcombinator :exps, exps
end
