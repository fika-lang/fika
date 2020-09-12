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

  describe "function definition" do
    test "without args or type" do
      str = """
      fn foo do
        123
      end
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.function_def(str)

      assert result == [
        {:function, [position: {3, 16, 19}],
          {:foo, [], {:type, {1, 0, 6}, "Nothing"}, [{:integer, {2, 10, 15}, 123}]}}
      ]
    end

    test "with return type" do
      str = """
      fn foo : Int do
        123
      end
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.function_def(str)

      assert result == [
        {:function, [position: {3, 22, 25}],
          {:foo, [], {:type, {1, 0, 12}, "Int"}, [{:integer, {2, 16, 21}, 123}]}}
      ]
    end

  test "with args" do
    str = """
    fn foo(x: Int, y: Int) : Int do
      x + y
    end
    """

    {:ok, result, _rest, _context, _line, _byte_offset} = Parser.function_def(str)

    assert result == [
      {:function, [position: {3, 40, 43}],
        {:foo,
          [
            {{:identifier, {1, 0, 8}, :x}, {:type, {1, 0, 13}, "Int"}},
            {{:identifier, {1, 0, 16}, :y}, {:type, {1, 0, 21}, "Int"}}
          ],
          {:type, {1, 0, 28}, "Int"},
          [
            {:call, {:+, {2, 32, 39}},
              [{:identifier, {2, 32, 35}, :x}, {:identifier, {2, 32, 39}, :y}], :kernel}
          ]
        }
      }
    ]
  end
  end
end
