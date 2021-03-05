defmodule Fika.Compiler.Parser.PatternTest do
  use ExUnit.Case, async: true

  test "string literal" do
    str = """
    "Hello"
    """

    assert {:string, {1, 0, 7}, ["Hello"]} == TestParser.pattern!(str)
  end

  test "integer literal" do
    str = "123"
    assert {:integer, {1, 0, 3}, 123} == TestParser.pattern!(str)
  end

  test "atom literal" do
    str = ":a"
    assert {:atom, {1, 0, 2}, :a} == TestParser.pattern!(str)
  end

  test "identifier" do
    str = "x"
    assert {:identifier, {1, 0, 1}, :x} == TestParser.pattern!(str)
  end

  test "tuple pattern" do
    str = "{:ok, name}"

    assert {
             :tuple,
             {1, 0, 11},
             [
               {:atom, {1, 0, 4}, :ok},
               {:identifier, {1, 0, 10}, :name}
             ]
           } == TestParser.pattern!(str)
  end

  test "record pattern" do
    str = "{foo: \"bar\"}"

    assert {:record, {1, 0, 12}, nil,
            [{{:identifier, {1, 0, 4}, :foo}, {:string, {1, 0, 11}, ["bar"]}}]} ==
             TestParser.pattern!(str)
  end
end
