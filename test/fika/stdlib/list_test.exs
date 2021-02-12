defmodule Fika.Stdlib.ListTest do
  use ExUnit.Case, async: false

  alias Fika.Code

  test "map" do
    str = """
    fn add_one(x: List(Int)) : List(Int) do
      list.map(x, (y : Int) do
        y + 1
      end)
    end
    """

    Code.load_file("foo", str)

    assert apply(:foo, :add_one, [[1, 2, 3]]) == [2, 3, 4]
  end

  test "length" do
    str = """
    fn count(x: List(Int)) : Int do
      list.length(x)
    end
    """

    Code.load_file("foo", str)

    assert apply(:foo, :count, [[1, 2, 3]]) == 3
  end

  test "filter" do
    str = """
    fn filter_nums(x: List(Int)) : List(Int) do
      list.filter(x, (y: Int) do
        y == 3 | y == 5
      end)
    end
    """

    Code.load_file("foo", str)

    assert apply(:foo, :filter_nums, [[1, 2, 3, 4, 5]]) == [3, 5]
  end

  test "reduce/3" do
    str = """
    fn sum(x: List(Int)) : Int do
      list.reduce(x, 0, (y: Int, acc: Int) do
        y + acc
      end)
    end
    """

    Code.load_file("foo", str)

    assert apply(:foo, :sum, [[1, 2, 3, 4, 5]]) == 15
  end

  test "reduce/2" do
    str = """
    fn sum(x: List(Int)) : Int do
      list.reduce(x, (y: Int, acc: Int) do
        y + acc
      end)
    end
    """

    Code.load_file("foo", str)

    assert apply(:foo, :sum, [[1, 2, 3, 4, 5]]) == 15
  end
end
