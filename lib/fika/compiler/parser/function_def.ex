defmodule Fika.Compiler.Parser.FunctionDef do
  import NimbleParsec

  alias Fika.Compiler.Parser.{
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
    |> repeat(
      allow_space
      |> ignore(string(","))
      |> concat(allow_space)
      |> concat(arg)
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

  arg_names =
    identifier
    |> repeat(
      allow_space
      |> ignore(string(","))
      |> concat(allow_space)
      |> concat(identifier)
    )

  arg_list =
    choice([
      ignore(string("["))
      |> concat(allow_space)
      |> wrap(arg_names)
      |> concat(allow_space)
      |> ignore(string("]")),
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

  public_function_def =
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
    |> Helper.to_ast(:public_function_def)

  ext_atom =
    ignore(string("\""))
    |> repeat(choice([string("\\\""), utf8_char(not: ?")]))
    |> ignore(string("\""))
    |> Helper.to_ast(:ext_atom)

  ext_function_def =
    ignore(string("ext"))
    |> concat(require_space)
    |> concat(identifier)
    |> concat(arg_parens)
    |> concat(return_type)
    |> concat(allow_space)
    |> ignore(string("="))
    |> concat(allow_space)
    |> ignore(string("{"))
    |> concat(allow_space)
    |> concat(ext_atom)
    |> concat(allow_space)
    |> ignore(string(","))
    |> concat(allow_space)
    |> concat(ext_atom)
    |> concat(allow_space)
    |> ignore(string(","))
    |> concat(allow_space)
    |> concat(arg_list)
    |> concat(allow_space)
    |> ignore(string("}"))
    |> label("external function definition")
    |> Helper.to_ast(:ext_function_def)

  function_def =
    choice([
      public_function_def,
      ext_function_def
    ])

  function_defs =
    allow_space
    |> concat(function_def)
    |> times(min: 1)

  defcombinatorp :args, args
  defcombinator :function_def, function_def
  defcombinator :function_defs, function_defs
end
