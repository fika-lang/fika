defmodule Fika.Types.Record do
  defstruct [:fields]

  alias Fika.Types, as: T

  defimpl String.Chars, for: T.Record do
    def to_string(%{fields: fields}) do
      str =
        fields
        |> Enum.map(fn {k, v} ->
          "#{k}: #{v}"
        end)
        |> T.Helper.join_list()

      "{#{str}}"
    end
  end
end
