defmodule Fika.ParserTest do
  use ExUnit.Case
  alias Fika.Parser

  describe "expressions" do
    test "integer" do
      str = """
      123
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)
      assert result ==  [{:integer, {1, 0, 3}, 123}]
    end
  end
end
