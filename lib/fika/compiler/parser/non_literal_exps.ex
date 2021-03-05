defmodule Fika.Compiler.Parser.NonLiteralExps do
  import NimbleParsec

  alias Fika.Compiler.Parser.{Common, Helper, Expressions, FunctionDef, Pattern}

  allow_space = parsec({Common, :allow_space})
  require_space = parsec({Common, :require_space})
  identifier = parsec({Common, :identifier})
  module_name = parsec({Common, :module_name})
  exp = parsec({Expressions, :exp})
  exps = parsec({Expressions, :exps})
  exp_delimiter = parsec({Expressions, :exp_delimiter})
  args = parsec({FunctionDef, :args})
  pattern = parsec({Pattern, :pattern})

  exp_paren =
    ignore(string("("))
    |> concat(exp)
    |> ignore(string(")"))
    |> label("expression in parentheses")

  call_args =
    optional(
      exp
      |> optional(
        allow_space
        |> ignore(string(","))
        |> concat(allow_space)
        |> parsec(:call_args)
      )
    )

  local_function_call =
    identifier
    |> ignore(string("("))
    |> wrap(call_args)
    |> ignore(string(")"))
    |> Helper.to_ast(:local_function_call)

  remote_function_call =
    module_name
    |> ignore(string("."))
    |> concat(identifier)
    |> ignore(string("("))
    |> wrap(call_args)
    |> ignore(string(")"))
    |> Helper.to_ast(:remote_function_call)

  function_call =
    choice([
      remote_function_call,
      local_function_call
    ])
    |> label("function call")

  arg_parens =
    ignore(string("("))
    |> concat(allow_space)
    |> wrap(optional(args))
    |> concat(allow_space)
    |> ignore(string(")"))

  anonymous_function =
    arg_parens
    |> concat(allow_space)
    |> ignore(string("do"))
    |> concat(allow_space)
    |> wrap(exps)
    |> concat(allow_space)
    |> ignore(string("end"))
    |> label("anonymous function")
    |> Helper.to_ast(:anonymous_function)

  # TO-DO: accept nested if-else expressions
  exp_if_else =
    ignore(string("if"))
    |> concat(require_space)
    |> concat(exp)
    |> concat(require_space)
    |> ignore(string("do"))
    |> concat(require_space)
    |> wrap(exps)
    |> concat(require_space)
    |> ignore(string("else"))
    |> concat(require_space)
    |> wrap(exps)
    |> concat(require_space)
    |> ignore(string("end"))
    |> label("if-else expression")
    |> Helper.to_ast(:exp_if_else)

  case_exp =
    exp
    |> lookahead_not(string(" ->"))

  case_block =
    case_exp
    |> repeat(
      times(exp_delimiter, min: 1)
      |> concat(case_exp)
    )

  case_clause =
    pattern
    |> concat(allow_space)
    |> ignore(string("->"))
    |> concat(allow_space)
    |> wrap(case_block)
    |> concat(allow_space)

  exp_case =
    ignore(string("case"))
    |> concat(require_space)
    |> concat(exp)
    |> concat(require_space)
    |> ignore(string("do"))
    |> concat(require_space)
    |> wrap(times(wrap(case_clause), min: 1))
    |> ignore(string("end"))
    |> label("case expression")
    |> Helper.to_ast(:exp_case)

  function_ref_call =
    ignore(string("."))
    |> ignore(string("("))
    |> wrap(call_args)
    |> ignore(string(")"))

  non_literal_exps =
    choice([
      exp_paren,
      function_call,
      identifier,
      exp_if_else,
      exp_case,
      anonymous_function
    ])
    |> optional(function_ref_call)
    |> Helper.to_ast(:function_ref_call)

  defcombinatorp :call_args, call_args
  defcombinator :non_literal_exps, non_literal_exps
end
