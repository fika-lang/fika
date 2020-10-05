defmodule Fika.Parser.Expressions do
  import NimbleParsec

  alias Fika.Parser.{Common, Helper, LiteralExps, NonLiteralExps}

  allow_space = parsec({Common, :allow_space})
  require_space = parsec({Common, :require_space})
  identifier = parsec({Common, :identifier})
  literal_exps = parsec({LiteralExps, :literal_exps})
  non_literal_exps = parsec({NonLiteralExps, :non_literal_exps})

  exp_match =
    identifier
    |> concat(allow_space)
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
      allow_space
      |> choice([string("*"), string("/")])
      |> concat(allow_space)
      |> parsec(:term)
    )

  exp_mult_op = Helper.to_ast(term, :exp_bin_op)

  exp_bin_op =
    exp_mult_op
    |> optional(
      allow_space
      |> choice([string("+"), string("-")])
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

  exps =
    parsec(:exp)
    |> optional(
      require_space
      |> parsec(:exps)
    )

  defcombinatorp :exp_bin_op, exp_bin_op
  defcombinatorp :term, term
  defcombinator :exp, exp
  defcombinator :exps, exps
end
