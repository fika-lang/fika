defmodule Fika.Parser.FunctionDef do
  import NimbleParsec

  alias Fika.Parser.{
    Common,
    Types,
    Helper,
    Expressions
  }

  allow_space = parsec({Common, :allow_space})
  require_space = parsec({Common, :require_space})
  identifier = parsec({Common, :identifier})
  parse_type = parsec({Types, :parse_type})
  exps = parsec({Expressions, :exps})

  arg =
    identifier
    |> concat(allow_space)
    |> ignore(string(":"))
    |> concat(allow_space)
    |> concat(parse_type)
    |> Helper.to_ast(:arg)

  args =
    arg
    |> optional(
      allow_space
      |> ignore(string(","))
      |> concat(allow_space)
      |> parsec(:args)
    )

  arg_parens =
    choice([
      ignore(string("("))
      |> concat(allow_space)
      |> wrap(args)
      |> concat(allow_space)
      |> ignore(string(")")),
      empty() |> wrap()
    ])

  return_type =
    optional(
      allow_space
      |> ignore(string(":"))
      |> concat(allow_space)
      |> concat(parse_type)
    )
    |> Helper.to_ast(:return_type)

  function_def =
    allow_space
    |> ignore(string("fn"))
    |> concat(require_space)
    |> concat(identifier)
    |> concat(arg_parens)
    |> concat(return_type)
    |> concat(require_space)
    |> ignore(string("do"))
    |> concat(require_space)
    |> wrap(exps)
    |> concat(require_space)
    |> ignore(string("end"))
    |> label("function definition")
    |> Helper.to_ast(:function_def)

  function_defs =
    allow_space
    |> concat(function_def)
    |> times(min: 1)

  defcombinatorp :args, args
  defcombinator :function_defs, function_defs
end
