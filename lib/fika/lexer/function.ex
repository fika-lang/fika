defmodule Fika.Lexer.Function do
  @moduledoc """
  Defines identifier lexemes
  """

  import NimbleParsec
  alias Fika.ParserHelper, as: Helper

  alias Fika.Lexer.Lexemes, as: LX
  alias Fika.Lexer.Lexemes.Identifier

  alias Fika.Lexer.{
    Expression,
    Type
  }

  def function_ref do
    ignore(string("&"))
    |> wrap(optional(Identifier.identifier() |> ignore(string("."))))
    |> concat(Identifier.identifier())
    |> wrap(optional(function_ref_type_parens()))
    |> Helper.to_ast(:function_ref)
  end

  def exp_paren do
    ignore(LX.l_paren())
    |> parsec(:exp)
    |> ignore(LX.r_paren())
    |> label("expression in parentheses")
  end

  def call_args do
    optional(
      parsec(:exp)
      |> optional(
        LX.allow_space()
        |> ignore(LX.comma())
        |> concat(LX.allow_space())
        |> parsec(:call_args)
      )
    )
  end

  def function_ref_call do
    ignore(string("."))
    |> ignore(LX.l_paren())
    |> wrap(call_args())
    |> ignore(LX.r_paren())
  end

  def local_function_call do
    Identifier.identifier()
    |> ignore(LX.l_paren())
    |> wrap(call_args())
    |> ignore(LX.r_paren())
    |> Helper.to_ast(:local_function_call)
  end

  def remote_function_call do
    Identifier.identifier()
    |> ignore(string("."))
    |> concat(Identifier.identifier())
    |> ignore(LX.l_paren())
    |> wrap(call_args())
    |> ignore(LX.r_paren())
    |> Helper.to_ast(:remote_function_call)
  end

  def function_call do
    choice([
      remote_function_call(),
      local_function_call()
    ])
    |> label("function call")
  end

  def function_def do
    LX.allow_space()
    |> ignore(string("fn"))
    |> concat(LX.require_space())
    |> concat(Identifier.identifier())
    |> concat(arg_parens())
    |> concat(return_type())
    |> concat(LX.require_space())
    |> ignore(string("do"))
    |> concat(LX.require_space())
    |> wrap(Expression.exps())
    |> concat(LX.require_space())
    |> ignore(string("end"))
    |> label("function definition")
    |> Helper.to_ast(:function_def)
  end

  defp function_ref_type_parens do
    ignore(LX.l_paren())
    |> concat(LX.allow_space())
    |> parsec(:type)
    |> concat(Type.type_args_list())
    |> ignore(LX.r_paren())
  end

  defp arg do
    Identifier.identifier()
    |> concat(LX.allow_space())
    |> ignore(string(":"))
    |> concat(LX.allow_space())
    |> concat(Type.parse_type())
    |> Helper.to_ast(:arg)
  end

  def args do
    arg()
    |> optional(
      LX.allow_space()
      |> ignore(LX.comma())
      |> concat(LX.allow_space())
      |> parsec(:args)
    )
  end

  defp arg_parens do
    choice([
      ignore(LX.l_paren())
      |> concat(LX.allow_space())
      |> wrap(args())
      |> concat(LX.allow_space())
      |> ignore(LX.r_paren()),
      empty() |> wrap()
    ])
  end

  defp return_type do
    optional(
      LX.allow_space()
      |> ignore(string(":"))
      |> concat(LX.allow_space())
      |> concat(Type.parse_type())
    )
    |> Helper.to_ast(:return_type)
  end
end
