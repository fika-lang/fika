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

  unary_exp =
    choice([
      choice([string("!"), string("-")])
      |> concat(allow_space)
      |> concat(factor)
      |> Helper.to_ast(:unary_op),
      factor
    ])

  exp_mult_op =
    unary_exp
    |> optional(
      allow_horizontal_space
      |> choice([string("*"), string("/")])
      |> concat(allow_space)
      |> parsec(:exp_mult_op)
    )

  exp_mult = Helper.to_ast(exp_mult_op, :exp_bin_op)

  exp_add_op =
    exp_mult
    |> optional(
      allow_horizontal_space
      |> choice([string("+"), string("-")])
      |> concat(allow_space)
      |> parsec(:exp_add_op)
    )

  exp_add = Helper.to_ast(exp_add_op, :exp_bin_op)

  exp_rel_op =
    exp_add
    |> optional(
      allow_horizontal_space
      |> choice([string("<="), string(">="), string("<"), string(">")])
      |> concat(allow_space)
      |> parsec(:exp_rel_op)
    )

  exp_rel = Helper.to_ast(exp_rel_op, :exp_bin_op)

  exp_comp_op =
    exp_rel
    |> optional(
      allow_horizontal_space
      |> choice([string("=="), string("!=")])
      |> concat(allow_space)
      |> parsec(:exp_comp_op)
    )

  exp_comp = Helper.to_ast(exp_comp_op, :exp_bin_op)

  exp_and_op =
    exp_comp
    |> optional(
      allow_horizontal_space
      |> concat(string("&"))
      |> concat(allow_space)
      |> parsec(:exp_and_op)
    )

  exp_and = Helper.to_ast(exp_and_op, :exp_bin_op)

  exp_or_op =
    exp_and
    |> optional(
      allow_horizontal_space
      |> concat(string("|"))
      |> concat(allow_space)
      |> parsec(:exp_or_op)
    )

  exp_or = Helper.to_ast(exp_or_op, :exp_bin_op)

  exp =
    choice([
      exp_match,
      exp_or
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

  defcombinatorp :exp_mult_op, exp_mult_op
  defcombinatorp :exp_add_op, exp_add_op
  defcombinatorp :exp_rel_op, exp_rel_op
  defcombinatorp :exp_comp_op, exp_comp_op
  defcombinatorp :exp_and_op, exp_and_op
  defcombinatorp :exp_or_op, exp_or_op
  defcombinator :factor, factor
  defcombinator :exp, exp
  defcombinator :exps, exps
end
