defmodule Fika.Types do
  @moduledoc """
  This module contains the types in Fika which are implemented using structs
  """

  defmodule FunctionRef do
    defstruct [:arg_types, :return_type]

    defimpl String.Chars, for: FunctionRef do
      def to_string(%{arg_types: arg_types, return_type: return_type}) do
        args = Enum.join(arg_types, ",")
        "Fn(#{args}->#{return_type})"
      end
    end
  end
end
