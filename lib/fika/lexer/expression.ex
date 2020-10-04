defmodule Fika.Lexer.Expression do
  @moduledoc """
  Defines some basic lexemes which can be used by other `Fika.Lexer` submodules.
  """

  import NimbleParsec
  alias Fika.ParserHelper, as: Helper

  alias Fika.Lexer.Lexemes, as: LX

  alias Fika.Lexer.{
    Function,
    If
  }

  alias LX.{
    Atom,
    ListLike,
    Identifier,
    Number,
    Record,
    String
  }

  def literals do
    choice([
      Number.integer(),
      Atom.boolean(),
      String.string(),
      ListLike.list(),
      ListLike.tuple(),
      Record.record(),
      Function.function_ref(),
      Atom.atom(),
      If.if()
    ])
  end

  defp non_literals do
    choice([
      Function.exp_paren(),
      Function.function_call(),
      Identifier.identifier()
    ])
    |> optional(Function.function_ref_call())
    |> Helper.to_ast(:function_ref_call)
  end

  defp factor do
    choice([
      literals(),
      non_literals()
    ])
  end

  def term do
    factor()
    |> optional(
      LX.allow_space()
      |> choice([string("*"), string("/")])
      |> concat(LX.allow_space())
      |> parsec(:term)
    )
  end

  defp exp_mult_op, do: Helper.to_ast(term(), :exp_bin_op)

  def exp_bin_op do
    exp_mult_op()
    |> optional(
      LX.allow_space()
      |> choice([string("+"), string("-")])
      |> concat(LX.allow_space())
      |> parsec(:exp_bin_op)
    )
  end

  defp exp_add_op, do: Helper.to_ast(exp_bin_op(), :exp_bin_op)

  defp exp_match do
    Identifier.identifier()
    |> concat(LX.allow_space())
    |> ignore(string("="))
    |> concat(LX.allow_space())
    |> parsec(:exp)
    |> label("match expression")
    |> Helper.to_ast(:exp_match)
  end

  def exp do
    choice([
      exp_match(),
      exp_add_op()
    ])
    |> label("expression")
  end

  def exps do
    parsec(:exp)
    |> optional(
      LX.require_space()
      |> parsec(:exps)
    )
  end
end
