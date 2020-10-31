defmodule Fika.Types.Tuple do
  defstruct elements: %Fika.Types.ArgList{}

  defimpl String.Chars, for: Fika.Types.Tuple do
    @spec to_string(%{elements: any}) :: <<_::16, _::_*8>>
    def to_string(%{elements: elements}) do
      "{#{elements}}"
    end
  end
end
