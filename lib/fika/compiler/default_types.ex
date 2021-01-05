defmodule Fika.Compiler.DefaultTypes do
  @moduledoc """
  This module holds the type signatures of the functions which are included
  by default in Fika, but are defined externally in erlang or elixir.
  """

  alias Fika.Compiler.TypeChecker.Types, as: T
  alias Fika.Compiler.FunctionSignature

  def kernel do
    m = "fika/kernel"

    %{
      s(m, "+", [:Int, :Int]) => :Int,
      s(m, "+", [:Int, :Float]) => :Float,
      s(m, "+", [:Float, :Int]) => :Float,
      s(m, "+", [:Float, :Float]) => :Float,
      s(m, "-", [:Int, :Int]) => :Int,
      s(m, "-", [:Int, :Float]) => :Float,
      s(m, "-", [:Float, :Int]) => :Float,
      s(m, "-", [:Float, :Float]) => :Float,
      s(m, "*", [:Int, :Int]) => :Int,
      s(m, "*", [:Int, :Float]) => :Float,
      s(m, "*", [:Float, :Int]) => :Float,
      s(m, "*", [:Float, :Float]) => :Float,
      s(m, "/", [:Int, :Int]) => :Float,
      s(m, "/", [:Int, :Float]) => :Float,
      s(m, "/", [:Float, :Int]) => :Float,
      s(m, "/", [:Float, :Float]) => :Float,
      s(m, "|", [:Bool, :Bool]) => :Bool,
      s(m, "&", [:Bool, :Bool]) => :Bool,
      s(m, "!", [:Bool]) => :Bool,
      s(m, "-", [:Int]) => :Int,
      s(m, "<", [:Int, :Int]) => :Bool,
      s(m, ">", [:Int, :Int]) => :Bool,
      s(m, "<=", [:Int, :Int]) => :Bool,
      s(m, ">=", [:Int, :Int]) => :Bool,
      s(m, "==", [:Int, :Int]) => :Bool,
      s(m, "!=", [:Int, :Int]) => :Bool
    }
  end

  def io do
    m = "fika/io"

    %{
      s(m, "gets", [:String]) => %T.Effect{type: :String},
      s(m, "puts", [:String]) => %T.Effect{type: :String}
    }
  end

  # Helper function to create signature structs out of module, function and
  # arg types.
  defp s(m, f, t) do
    %FunctionSignature{module: m, function: f, types: t}
  end
end
