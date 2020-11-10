defmodule Fika.Compiler.TypeChecker.Types.Helper do
  @moduledoc """
  Helper functions for dealing with types
  """

  def join_list(arg_list) when is_list(arg_list) do
    Enum.join(arg_list, ", ")
  end
end
