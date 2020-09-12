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

    test "arithmetic with add and mult" do
      str = """
      2 + 3 * 4
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [{
        :call, {:+, {1, 0, 9}},
          [
            {:integer, {1, 0, 1}, 2},
            {:call, {:*, {1, 0, 9}}, [{:integer, {1, 0, 5}, 3},
              {:integer, {1, 0, 9}, 4}], :kernel}
          ], :kernel
      }]
    end

    test "add/sub has less precedence than mult/div" do
      str = """
      10 + 20 * 30 - 40 / 50
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [{
          :call,
          {:-, {1, 0, 22}},
          [
            {:call, {:+, {1, 0, 22}}, [{:integer, {1, 0, 2}, 10},
              {:call, {:*, {1, 0, 12}}, [{:integer, {1, 0, 7}, 20},
                {:integer, {1, 0, 12}, 30}], :kernel}], :kernel},
              {:call, {:/, {1, 0, 22}}, [{:integer, {1, 0, 17}, 40},
                {:integer, {1, 0, 22}, 50}], :kernel}
          ], :kernel
        }]
    end

    test "grouping using parens" do
      str = """
      (10 + 20) * (30 - 40) / 50
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [
        {
          :call,
          {:/, {1, 0, 26}},
          [
            {
              :call,
              {:*, {1, 0, 26}},
                [
                  {:call, {:+, {1, 0, 8}}, [{:integer,
                    {1, 0, 3}, 10}, {:integer, {1, 0, 8}, 20}], :kernel},
                  {:call, {:-, {1, 0, 20}}, [{:integer, {1, 0, 15}, 30},
                    {:integer, {1, 0, 20}, 40}], :kernel}
                ],
                :kernel
            },
                {:integer, {1, 0, 26}, 50}
          ], :kernel}
      ]
    end
  end
end
