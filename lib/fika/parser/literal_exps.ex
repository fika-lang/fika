defmodule Fika.Parser.LiteralExps do
  import NimbleParsec

  alias Fika.Parser.{Common, Helper, Types, Expressions}

  allow_space = parsec({Common, :allow_space})
  identifier = parsec({Common, :identifier})
  atom = parsec({Common, :atom})
  type = parsec({Types, :type})
  exp = parsec({Expressions, :exp})

  integer =
    integer(min: 1)
    |> label("integer")
    |> Helper.to_ast(:integer)

  boolean =
    choice([
      string("true"),
      string("false")
    ])
    |> label("boolean")
    |> Helper.to_ast(:boolean)

  string_exp =
    ignore(string("\""))
    |> repeat(choice([string("\\\""), utf8_char(not: ?")]))
    |> ignore(string("\""))
    |> Helper.to_ast(:string)

  list_rest =
    ignore(string(","))
    |> concat(allow_space)
    |> concat(exp)

  list_content =
    exp
    |> concat(allow_space)
    |> repeat(list_rest)

  exp_list =
    ignore(string("["))
    |> concat(allow_space)
    |> optional(list_content)
    |> concat(allow_space)
    |> ignore(string("]"))
    |> Helper.to_ast(:exp_list)

  tuple =
    ignore(string("{"))
    |> concat(allow_space)
    |> concat(list_content)
    |> concat(allow_space)
    |> ignore(string("}"))
    |> Helper.to_ast(:tuple)

  key_value =
    allow_space
    |> concat(identifier)
    |> concat(allow_space)
    |> ignore(string(":"))
    |> concat(allow_space)
    |> concat(exp)
    |> label("key value pair")
    |> Helper.to_ast(:key_value)

  record =
    wrap(optional(string("Foo")))
    |> ignore(string("{"))
    |> concat(key_value)
    |> repeat(
      allow_space
      |> ignore(string(","))
      |> concat(allow_space)
      |> concat(key_value)
    )
    |> optional(ignore(string(",")))
    |> ignore(string("}"))
    |> label("record")
    |> Helper.to_ast(:record)

  type_args_list =
    optional(
      allow_space
      |> ignore(string(","))
      |> concat(allow_space)
      |> concat(type)
      |> parsec(:type_args_list)
    )

  function_ref_type_parens =
    ignore(string("("))
    |> concat(allow_space)
    |> concat(type)
    |> concat(type_args_list)
    |> ignore(string(")"))

  function_ref =
    ignore(string("&"))
    |> wrap(optional(identifier |> ignore(string("."))))
    |> concat(identifier)
    |> wrap(optional(function_ref_type_parens))
    |> Helper.to_ast(:function_ref)

  literal_exps =
    choice([
      integer,
      boolean,
      string_exp,
      exp_list,
      tuple,
      record,
      function_ref,
      atom
    ])

  defcombinatorp :type_args_list, type_args_list
  defcombinator :literal_exps, literal_exps
end
