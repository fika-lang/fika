defmodule Fika.Types.Record do
  defstruct [:fields]

  defimpl String.Chars, for: Fika.Types.Record do
    def to_string(%{fields: fields}) do
      str =
        fields
        |> Enum.map(fn {k, v} ->
          "#{k}: #{v}"
        end)
        |> Enum.join(", ")

      "{#{str}}"
    end
  end
end
