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

  require_space =
    space
    |> times(min: 1)
    |> ignore()

  allow_space =
    space
    |> repeat()
    |> ignore()

  keyword =
    choice([
      string("fn"),
      string("do"),
      string("end")
    ])

  identifier =
    lookahead_not(keyword)
    |> ascii_string([?a..?z], 1)
    |> ascii_string([?a..?z, ?_, ?0..?9], min: 0)
    |> reduce({Enum, :join, [""]})
    |> label("identifier")
    |> Helper.to_ast(:identifier)

  simple_type =
    ascii_string([?A..?Z], 1)
    |> ascii_string([?a..?z, ?A..?Z], min: 0)
    |> reduce({Enum, :join, [""]})
    |> Helper.to_ast(:simple_type)

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

  exps =
    parsec(:exp)
    |> optional(
      require_space
      |> parsec(:exps)
    )

  # Right now it's just simple one-worded types.
  # More complex types will come in here.
  type =
    simple_type

  return_type =
    optional(
      allow_space
      |> ignore(string(":"))
      |> concat(allow_space)
      |> concat(type)
    )
    |> Helper.to_ast(:return_type)

  function_def =
    allow_space
    |> ignore(string("fn"))
    |> concat(require_space)
    |> concat(identifier)
    |> concat(return_type)
    |> concat(require_space)
    |> ignore(string("do"))
    |> concat(require_space)
    |> wrap(exps)
    |> concat(require_space)
    |> ignore(string("end"))
    |> label("function definition")
    |> Helper.to_ast(:function_def)

  module =
    function_def
    |> times(min: 1)
    |> concat(allow_space)
    |> eos()

  def parse_module(str, module_name) do
    {:ok, ast, _, _, _, _} = parse(str)
    {:module, module_name, ast}
  end

  defcombinatorp :exp, exp
  defcombinatorp :exps, exps
  defcombinatorp :exp_bin_op, exp_bin_op
  defcombinatorp :term, term

  defparsec :parse, module

  # For testing
  defparsec :expression, exp |> concat(allow_space) |> eos()
  defparsec :function_def, function_def
end
