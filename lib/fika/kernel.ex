defmodule Fika.Kernel do
  @moduledoc """
  This module right now only has a function named types which returns a map
  of known function types belonging to kernel. In the future, this module will
  be moved to a .fi file.
  """

  def types do
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
end
