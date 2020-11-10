defmodule Fika.Compiler.ErlTranslateTest do
  use ExUnit.Case, async: true

  alias Fika.Compiler.{
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

    {:ok, ast} = Parser.parse_module(str)
    result = ErlTranslate.translate(ast, :test, "/tmp/foo")

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

  test "arithmetic operators" do
    str = """
    fn a do
      1+2*-3/4
    end
    """

    {:ok, ast} = Parser.parse_module(str)
    result = ErlTranslate.translate(ast, :test, "/tmp/foo")

    forms = [
      {:attribute, 1, :file, {'/tmp/foo', 1}},
      {:attribute, 1, :module, :test},
      {:attribute, 3, :export, [a: 0]},
      {:function, 3, :a, 0,
       [
         {:clause, 3, [], [],
          [
            {:op, 2, :+, {:integer, 2, 1},
             {:op, 2, :/, {:op, 2, :*, {:integer, 2, 2}, {:op, 2, :-, {:integer, 2, 3}}},
              {:integer, 2, 4}}}
          ]}
       ]}
    ]

    assert result == forms
  end

  test "logical operators" do
    str = "(true | !false) & true"

    ast = TestParser.expression!(str)

    assert {:op, 1, :and, {:op, 1, :or, {:atom, 1, true}, {:op, 1, :not, {:atom, 1, false}}},
            {:atom, 1, true}} = ErlTranslate.translate_expression(ast)
  end

  test "logical operators precedence" do
    str = "false | true & !true"
    ast = TestParser.expression!(str)

    assert {:op, _, :or, {:atom, _, false},
            {:op, _, :and, {:atom, _, true}, {:op, _, :not, {:atom, _, true}}}} =
             ErlTranslate.translate_expression(ast)
  end

  test "record" do
    str = "{foo: 1}"
    ast = TestParser.expression!(str)
    result = ErlTranslate.translate_expression(ast)

    assert result ==
             {:map, 1,
              [
                {:map_field_assoc, 1, {:atom, 0, :__record__}, {nil, 0}},
                {:map_field_assoc, 1, {:atom, 1, :foo}, {:integer, 1, 1}}
              ]}
  end

  test "map" do
    str = ~s({"foo" => 1})
    ast = TestParser.expression!(str)
    result = ErlTranslate.translate_expression(ast)

    assert {:map, 1,
            [
              {:map_field_assoc, 1,
               {:bin, 1, [{:bin_element, 1, {:string, 1, 'foo'}, :default, :default}]},
               {:integer, 1, 1}}
            ]} = result
  end

  describe "function reference" do
    test "with module" do
      str = """
      use my_module
      &my_module.foo(Int, Int)
      """

      {:ok, [_, ast], _, _, _, _} = TestParser.exp_with_expanded_modules(str)
      result = ErlTranslate.translate_expression(ast)

      assert result ==
               {:fun, 2, {:function, {:atom, 2, :my_module}, {:atom, 2, :foo}, {:integer, 2, 2}}}
    end

    test "without module" do
      str = "&foo(Int, Int)"
      ast = TestParser.expression!(str)
      result = ErlTranslate.translate_expression(ast)

      assert result == {:fun, 1, {:function, :foo, 2}}
    end
  end

  describe "boolean" do
    Enum.each([true, false], fn bool ->
      test "#{bool} as boolean" do
        str = "#{unquote(bool)}"
        ast = TestParser.expression!(str)
        result = ErlTranslate.translate_expression(ast)

        assert result == {:atom, 1, unquote(bool)}
      end

      test "#{bool} as atom" do
        str = ":#{unquote(bool)}"
        ast = TestParser.expression!(str)
        result = ErlTranslate.translate_expression(ast)

        assert result == {:atom, 1, unquote(bool)}
      end
    end)
  end

  test "atom" do
    str = ":foo"
    ast = TestParser.expression!(str)
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

    ast = TestParser.expression!(str)
    result = ErlTranslate.translate_expression(ast)

    assert {:case, 5, {:atom, 1, true},
            [
              {:clause, 5, [{:atom, 5, true}], '',
               [{:bin, 2, [{:bin_element, 2, {:string, 2, 'foo'}, :default, :default}]}]},
              {:clause, 5, [{:atom, 5, false}], '',
               [{:bin, 4, [{:bin_element, 4, {:string, 4, 'bar'}, :default, :default}]}]}
            ]} = result
  end

  describe "string interpolation" do
    test "replaces with string" do
      str = ~S"""
      "#{"Hello"} #{"World"}"
      """

      ast = TestParser.expression!(str)
      result = ErlTranslate.translate_expression(ast)

      assert {:bin, 1,
              [
                {:bin_element, 1,
                 {:bin, 1, [{:bin_element, 1, {:string, 1, 'Hello'}, :default, :default}]},
                 :default, [:binary]},
                {:bin_element, 1, {:string, 1, ' '}, :default, :default},
                {:bin_element, 1,
                 {:bin, 1, [{:bin_element, 1, {:string, 1, 'World'}, :default, :default}]},
                 :default, [:binary]}
              ]} = result
    end

    test "parses known variable in string interpolation" do
      str = ~S"""
      hello = "Hello"
      "#{hello}"
      """

      {:ok, [_, interpolation], _, _, _, _} = TestParser.exps(str)

      result = ErlTranslate.translate_expression(interpolation)

      assert {:bin, 2, [{:bin_element, 2, {:var, 2, :hello}, :default, [:binary]}]} = result
    end
  end

  describe "tuple" do
    test "single element tuple" do
      str = "{1}"
      ast = TestParser.expression!(str)

      assert {:tuple, 1, [{:integer, 1, 1}]} = ErlTranslate.translate_expression(ast)
    end

    test "tuple of tuples" do
      str = "{{1}, {2}}"
      ast = TestParser.expression!(str)

      assert {
               :tuple,
               1,
               [{:tuple, 1, [{:integer, 1, 1}]}, {:tuple, 1, [{:integer, 1, 2}]}]
             } = ErlTranslate.translate_expression(ast)
    end
  end

  describe "list" do
    test "single element list" do
      str = "[1]"
      ast = TestParser.expression!(str)

      assert {:cons, 1, {:integer, 1, 1}, {nil, 1}} = ErlTranslate.translate_expression(ast)
    end

    test "list of lists" do
      str = "[[1], [1, 2]]"
      ast = TestParser.expression!(str)

      assert {:cons, 1, {:cons, 1, {:integer, 1, 1}, {nil, 1}},
              {:cons, 1, {:cons, 1, {:integer, 1, 1}, {:cons, 1, {:integer, 1, 2}, {nil, 1}}},
               {nil, 1}}} = ErlTranslate.translate_expression(ast)
    end
  end
end
