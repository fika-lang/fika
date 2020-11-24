defmodule Fika.Compiler.DefaultTypes do
  @moduledoc """
  This module holds the type signatures of the functions which are included
  by default in Fika, but are defined externally in erlang or elixir.
  """

  alias Fika.Compiler.TypeChecker.Types, as: T

  def kernel do
    %{
      "+(Int, Int)" => :Int,
      "+(Int, Float)" => :Float,
      "+(Float, Int)" => :Float,
      "+(Float, Float)" => :Float,
      "-(Int, Int)" => :Int,
      "-(Int, Float)" => :Float,
      "-(Float, Int)" => :Float,
      "-(Float, Float)" => :Float,
      "*(Int, Int)" => :Int,
      "*(Int, Float)" => :Float,
      "*(Float, Int)" => :Float,
      "*(Float, Float)" => :Float,
      "/(Int, Int)" => :Float,
      "/(Int, Float)" => :Float,
      "/(Float, Int)" => :Float,
      "/(Float, Float)" => :Float,
      "|(Bool, Bool)" => :Bool,
      "&(Bool, Bool)" => :Bool,
      "!(Bool)" => :Bool,
      "-(Int)" => :Int,
      "<(Int, Int)" => :Bool,
      ">(Int, Int)" => :Bool,
      "<=(Int, Int)" => :Bool,
      ">=(Int, Int)" => :Bool,
      "==(Int, Int)" => :Bool,
      "!=(Int, Int)" => :Bool
    }
  end

  def io do
    %{
      "gets(String)" => %T.Effect{type: :String},
      "puts(String)" => %T.Effect{type: :String}
    }
  end
end
