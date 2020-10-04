defmodule Fika.ErlTranslateTest do
  use ExUnit.Case

  alias Fika.{
    Parser,
    ErlTranslate
  }

  test "a function that calls another function" do
    str = """
    fn a do
      x = 1
      b(x)
    end

    fn b(x : Int) do
      x
    end
    """

    ast = Parser.parse_module(str, "test")
    result = ErlTranslate.translate(ast, "/tmp/foo")

    forms = [
      {:attribute, 1, :file, {'/tmp/foo', 1}},
      {:attribute, 1, :module, :test},
      {:attribute, 8, :export, [b: 1]},
      {:attribute, 4, :export, [a: 0]},
      {:function, 8, :b, 1, [{:clause, 8, [{:var, 6, :x}], [], [{:var, 7, :x}]}]},
      {:function, 4, :a, 0,
       [
         {:clause, 4, [], [],
          [
            {:match, 2, {:var, 2, :x}, {:integer, 2, 1}},
            {:call, 3, {:atom, 3, :b}, [{:var, 3, :x}]}
          ]}
       ]}
    ]

    assert result == forms
  end

  test "infix arithmetic operators" do
    str = """
    fn a do
      1+2*3/4
    end
    """

    ast = Parser.parse_module(str, "test_arithmetic")
    result = ErlTranslate.translate(ast, "/tmp/foo")

    forms = [
      {:attribute, 1, :file, {'/tmp/foo', 1}},
      {:attribute, 1, :module, :test_arithmetic},
      {:attribute, 3, :export, [a: 0]},
      {:function, 3, :a, 0,
       [
         {:clause, 3, [], [],
          [
            {:op, 2, :+, {:integer, 2, 1},
             {:op, 2, :/, {:op, 2, :*, {:integer, 2, 2}, {:integer, 2, 3}}, {:integer, 2, 4}}}
          ]}
       ]}
    ]

    assert result == forms
  end

  test "logical operators" do
    str = "(true || !false) && true"

    ast = Parser.expression!(str)

    assert {:op, 1, :and, {:op, 1, :or, {:atom, 1, true}, {:op, 1, :not, {:atom, 1, false}}},
            {:atom, 1, true}} = ErlTranslate.translate_expression(ast)
  end

  test "record" do
    str = "{foo: 1}"
    ast = Parser.expression!(str)
    result = ErlTranslate.translate_expression(ast)

    assert result ==
             {:map, 1,
              [
                {:map_field_assoc, 1, {:atom, 0, :__record__}, {nil, 0}},
                {:map_field_assoc, 1, {:atom, 1, :foo}, {:integer, 1, 1}}
              ]}
  end

  describe "function reference" do
    test "with module" do
      str = "&my_module.foo(Int, Int)"
      ast = Parser.expression!(str)
      result = ErlTranslate.translate_expression(ast)

      assert result ==
               {:fun, 1, {:function, {:atom, 1, :my_module}, {:atom, 1, :foo}, {:integer, 1, 2}}}
    end

    test "without module" do
      str = "&foo(Int, Int)"
      ast = Parser.expression!(str)
      result = ErlTranslate.translate_expression(ast)

      assert result == {:fun, 1, {:function, :foo, 2}}
    end
  end

  describe "boolean" do
    Enum.each([true, false], fn bool ->
      test "#{bool} as boolean" do
        str = "#{unquote(bool)}"
        ast = Parser.expression!(str)
        result = ErlTranslate.translate_expression(ast)

        assert result == {:atom, 1, unquote(bool)}
      end

      test "#{bool} as atom" do
        str = ":#{unquote(bool)}"
        ast = Parser.expression!(str)
        result = ErlTranslate.translate_expression(ast)

        assert result == {:atom, 1, unquote(bool)}
      end
    end)
  end

  test "atom" do
    str = ":foo"
    ast = Parser.expression!(str)
    result = ErlTranslate.translate_expression(ast)

    assert result == {:atom, 1, :foo}
  end

  test "if-else expression" do
    str = """
    if true do
      "foo"
    else
      "bar"
    end
    """

    ast = Fika.Parser.expression!(str)
    result = ErlTranslate.translate_expression(ast)

    assert {:case, 5, {:atom, 1, true},
            [
              {:clause, 5, [{:atom, 5, true}], [], [{:string, 2, 'foo'}]},
              {:clause, 5, [{:atom, 5, false}], [], [{:string, 4, 'bar'}]}
            ]} = result
  end

  describe "tuple" do
    test "single element tuple" do
      str = "{1}"
      ast = Fika.Parser.expression!(str)

      assert {:tuple, 1, [{:integer, 1, 1}]} = ErlTranslate.translate_expression(ast)
    end

    test "tuple of tuples" do
      str = "{{1}, {2}}"
      ast = Fika.Parser.expression!(str)

      assert {
               :tuple,
               1,
               [{:tuple, 1, [{:integer, 1, 1}]}, {:tuple, 1, [{:integer, 1, 2}]}]
             } = ErlTranslate.translate_expression(ast)
    end
  end
end
