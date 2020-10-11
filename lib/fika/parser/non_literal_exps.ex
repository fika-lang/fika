defmodule Fika.Parser.NonLiteralExps do
  import NimbleParsec

  alias Fika.Parser.{Common, Helper, Expressions}

  allow_space = parsec({Common, :allow_space})
  require_space = parsec({Common, :require_space})
  identifier = parsec({Common, :identifier})
  exp = parsec({Expressions, :exp})
  exps = parsec({Expressions, :exps})

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
    identifier
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

  function_ref_call =
    ignore(string("."))
    |> ignore(string("("))
    |> wrap(call_args)
    |> ignore(string(")"))

  not_op =
    string("!")
    |> concat(exp)
    |> Helper.to_ast(:not)

  non_literal_exps =
    choice([
      not_op,
      exp_paren,
      function_call,
      identifier,
      exp_if_else
    ])
    |> optional(function_ref_call)
    |> Helper.to_ast(:function_ref_call)

  defcombinatorp :call_args, call_args
  defcombinator :non_literal_exps, non_literal_exps
end
