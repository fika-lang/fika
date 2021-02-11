defmodule Fika.Compiler.DefaultTypes do
  @moduledoc """
  This module holds the type signatures of the functions which are included
  by default in Fika, but are defined externally in erlang or elixir.
  """

  alias Fika.Compiler.TypeChecker.Types, as: T
  alias Fika.Compiler.FunctionSignature

  def kernel do
    m = "fika/kernel"

    [
      s(m, "+", [:Int, :Int], :Int),
      s(m, "+", [:Int, :Float], :Float),
      s(m, "+", [:Float, :Int], :Float),
      s(m, "+", [:Float, :Float], :Float),
      s(m, "-", [:Int, :Int], :Int),
      s(m, "-", [:Int, :Float], :Float),
      s(m, "-", [:Float, :Int], :Float),
      s(m, "-", [:Float, :Float], :Float),
      s(m, "*", [:Int, :Int], :Int),
      s(m, "*", [:Int, :Float], :Float),
      s(m, "*", [:Float, :Int], :Float),
      s(m, "*", [:Float, :Float], :Float),
      s(m, "/", [:Int, :Int], :Float),
      s(m, "/", [:Int, :Float], :Float),
      s(m, "/", [:Float, :Int], :Float),
      s(m, "/", [:Float, :Float], :Float),
      s(m, "|", [:Bool, :Bool], :Bool),
      s(m, "&", [:Bool, :Bool], :Bool),
      s(m, "!", [:Bool], :Bool),
      s(m, "-", [:Int], :Int),
      s(m, "<", [:Int, :Int], :Bool),
      s(m, ">", [:Int, :Int], :Bool),
      s(m, "<=", [:Int, :Int], :Bool),
      s(m, ">=", [:Int, :Int], :Bool),
      s(m, "==", [:Int, :Int], :Bool),
      s(m, "!=", [:Int, :Int], :Bool)
    ]
  end

  # TODO: currently, the type signatures of stdlib functions are set
  # using the functions below. In the future, we should load these type
  # signatures automatically.
  def io do
    m = "fika/io"

    [
      s(m, "gets", [:String], %T.Effect{type: :String}),
      s(m, "puts", [:String], %T.Effect{type: :String})
    ]
  end

  def list do
    m = "fika/list"

    [
      s(m, "map", [
        %T.List{type: "a"},
        %T.FunctionRef{
          return_type: "b",
          arg_types: ["a"]
        }
      ], %T.List{type: "b"}),

      s(m, "length", [%T.List{type: "a"}], :Int),

      s(m, "filter", [
        %T.List{type: "a"},
        %T.FunctionRef{
          return_type: :Bool,
          arg_types: ["a"]
        }
      ], %T.List{type: "a"}),

      s(m, "reduce", [
        %T.List{type: "a"},
        %T.FunctionRef{
          return_type: "b",
          arg_types: ["a", "b"]
        }
      ], "b"),

      s(m, "reduce", [
        %T.List{type: "a"},
        "b",
        %T.FunctionRef{
          arg_types: ["a", "b"],
          return_type: "b"
        }
      ], "b"),
    ]
  end

  # Helper function to create signature structs out of module, function,
  # arg types and return type.
  defp s(m, f, t, r) do
    %FunctionSignature{module: m, function: f, types: t, return: r}
  end
end
