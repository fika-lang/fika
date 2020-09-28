defmodule Fika.Parser do
  import NimbleParsec

  alias Fika.ParserHelper, as: Helper

  horizontal_space =
    choice([
      string("\s"),
      string("\t")
    ])

  comment =
    string("#")
    |> repeat(utf8_char([not: ?\n]))
    |> string("\n")

  vertical_space =
    choice([
      string("\r"),
      string("\n")
    ])

  space =
    choice([vertical_space, horizontal_space, comment])
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

  identifier_str =
    ascii_string([?a..?z], 1)
    |> ascii_string([?a..?z, ?_, ?0..?9], min: 0)
    |> reduce({Enum, :join, [""]})
    |> label("snake_case string")

  identifier =
    lookahead_not(keyword)
    |> concat(identifier_str)
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

  boolean =
    choice([
      string("true"),
      string("false")
    ])
    |> label("boolean")
    |> Helper.to_ast(:boolean)

  string_exp =
    ignore(string("\""))
    |> repeat(choice([string("\\\""), utf8_char([not: ?"])]))
    |> ignore(string("\""))
    |> Helper.to_ast(:string)

  type_args_list =
    optional(
      allow_space
      |> ignore(string(","))
      |> concat(allow_space)
      |> parsec(:type)
      |> parsec(:type_args_list)
    )

  function_ref_type_parens =
    ignore(string("("))
    |> concat(allow_space)
    |> parsec(:type)
    |> concat(type_args_list)
    |> ignore(string(")"))

  function_ref =
    ignore(string("&"))
    |> wrap(optional(identifier |> ignore(string("."))))
    |> concat(identifier)
    |> wrap(optional(function_ref_type_parens))
    |> Helper.to_ast(:function_ref)

  list_rest =
    ignore(string(","))
    |> concat(allow_space)
    |> parsec(:exp)

  list_content =
    parsec(:exp)
    |> concat(allow_space)
    |> repeat(list_rest)

  exp_list =
    ignore(string("["))
    |> concat(allow_space)
    |> optional(list_content)
    |> concat(allow_space)
    |> ignore(string("]"))
    |> Helper.to_ast(:exp_list)

  exp_paren =
    ignore(string("("))
    |> parsec(:exp)
    |> ignore(string(")"))
    |> label("expression in parentheses")

  call_args =
    optional(
      parsec(:exp)
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

  exp_match =
    identifier
    |> concat(allow_space)
    |> ignore(string("="))
    |> concat(allow_space)
    |> parsec(:exp)
    |> label("match expression")
    |> Helper.to_ast(:exp_match)

  key_value =
    allow_space
    |> concat(identifier)
    |> concat(allow_space)
    |> ignore(string(":"))
    |> concat(allow_space)
    |> parsec(:exp)
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

  function_ref_call =
    ignore(string("."))
    |> ignore(string("("))
    |> wrap(call_args)
    |> ignore(string(")"))

  literal_exps =
    choice([
      integer,
      boolean,
      string_exp,
      exp_list,
      record,
      function_ref
    ])

  non_literal_exps =
    choice([
      exp_paren,
      function_call,
      identifier
    ])
    |> optional(function_ref_call)
    |> Helper.to_ast(:function_ref_call)

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

  type_args =
    optional(
      allow_space
      |> string(",")
      |> concat(allow_space)
      |> parsec(:type)
      |> parsec(:type_args)
    )

  type_parens =
    string("(")
    |> concat(allow_space)
    |> parsec(:type)
    |> concat(type_args)
    |> concat(allow_space)
    |> string(")")

  type_key_value =
    allow_space
    |> concat(identifier_str)
    |> concat(allow_space)
    |> string(":")
    |> concat(allow_space)
    |> parsec(:type)
    |> label("key value pair")
    |> reduce({Enum, :join, []})

  type_key_values =
    type_key_value
    |> repeat(
      allow_space
      |> ignore(string(","))
      |> concat(allow_space)
      |> concat(type_key_value)
    )
    |> reduce({Enum, :join, [","]})


  record_type =
    string("{")
    |> concat(type_key_values)
    |> string("}")
    |> reduce({Enum, :join, []})
    |> label("record type")

  function_type =
    string("Fn")
    |> string("(")
    |> optional(parsec(:type) |> concat(type_args))
    |> concat(allow_space)
    |> string("->")
    |> concat(allow_space)
    |> parsec(:type)
    |> string(")")

  type =
    choice([
      function_type,

      simple_type
      |> optional(type_parens),

      record_type
    ])

  parse_type =
    type
    |> Helper.to_ast(:type)

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

  exp_if_else =
    allow_space
    |> ignore(string("if"))
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

  module =
    function_def
    |> times(min: 1)
    |> concat(allow_space)
    |> eos()

  def parse_module(str, module_name) do
    {:ok, ast, _, _, _, _} = parse(str)
    {:module, module_name, ast}
  end

  def expression!(str) do
    {:ok, [result], _rest, _context, _line, _byte_offset} = expression(str)
    result
  end

  defcombinatorp :exp, exp
  defcombinatorp :exps, exps
  defcombinatorp :exp_bin_op, exp_bin_op
  defcombinatorp :term, term
  defcombinatorp :args, args
  defcombinatorp :call_args, call_args
  defcombinatorp :type, type
  defcombinatorp :type_args, type_args
  defcombinatorp :type_args_list, type_args_list

  defparsec :parse, module

  # For testing
  defparsec :expression, exp |> concat(allow_space) |> eos()
  defparsec :function_def, function_def
  defparsec :exp_if_else, exp_if_else
  defparsec :type_str, parse_type |> concat(allow_space) |> eos()
end
