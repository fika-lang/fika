defmodule Fika.ParserTest do
  use ExUnit.Case
  alias TestEvaluator, as: TE
  alias TestParser, as: TP

  alias Fika.Types, as: T

  test "integer" do
    str = """
    123
    """

    assert {:integer, {1, 0, 3}, 123} == TestParser.expression!(str)
  end

  describe "boolean" do
    test "true" do
      str = "true"

      assert {:boolean, {1, 0, 4}, true} == TestParser.expression!(str)
    end

    test "false" do
      str = "false"

      assert {:boolean, {1, 0, 5}, false} == TestParser.expression!(str)
    end
  end

  describe "atom" do
    test "parses multi-char atoms" do
      atom = :foobar
      str = ":#{atom}"

      assert {:atom, {1, 0, 7}, atom} == TestParser.expression!(str)
    end
  end

  describe "operators precedence" do
    # Table of all Fika operators, from higher to lower precedence.
    # Note that we respect Elixir operators precedence.
    #
    # Operator    Associativity   Description                               TODO
    # ----------------------------------------------------------------------------------------
    # .           Left            Dot operator                              Parser refactoring
    # ! -         Unary           Boolean not and arithmetic unary minus
    # * /         Left            Arithmetic binary mult and div
    # + -         Left            Arithmetic binary plus and minus
    # < > <= >=   Left            Comparison
    # == !=       Left            Comparison
    # &           Left            Boolean AND
    # |           Left            Boolean OR
    # =           Right           Match operator                            Parser refactoring
    # &           Unary           Capture operator                          Parser refactoring

    # These operators cannot be combined to form a valid expression but we test the parser anyway
    test "arithmetic binary * and / have less precedence than unary !" do
      assert {
               :call,
               {:*, {1, 0, 14}},
               [
                 {:integer, {1, 0, 1}, 1},
                 {:call, {:!, {1, 0, 14}}, [{:identifier, {1, 0, 14}, :something}], :kernel}
               ],
               :kernel
             } == TestParser.expression!("1 * !something")

      assert {
               :call,
               {:/, {1, 0, 14}},
               [
                 {:call, {:!, {1, 0, 10}}, [{:identifier, {1, 0, 10}, :something}], :kernel},
                 {:integer, {1, 0, 14}, 2}
               ],
               :kernel
             } == TestParser.expression!("!something / 2")
    end

    test "arithmetic binary * and / have less precedence than unary -" do
      assert {:ok, {-2, :Int, _}} = TE.eval("1 * -2")
      assert {:ok, {2.0, :Float, _}} = TE.eval("-10 / -5")
    end

    test "arithmetic binary + and - have less precedence than * and /" do
      assert {:ok, {12.5, :Float, _}} = TE.eval("1 / 2 + 3 * 4")
      assert {:ok, {3.0, :Float, _}} = TE.eval("1 * 5 - 4 / 2")
    end

    test "comparison operators <, >, <= and >= have less precedence than arithmetic + and -" do
      assert {:ok, {false, :Bool, _}} = TE.eval("1 + 2 < 4 - 1")
      assert {:ok, {true, :Bool, _}} = TE.eval("1 + 2 <= 4 - 1")
      assert {:ok, {false, :Bool, _}} = TE.eval("5 - 2 > 2 + 1")
      assert {:ok, {true, :Bool, _}} = TE.eval("5 - 2 >= 2 + 1")
    end

    # TODO: Test using evaluation instead of AST as soon as == and != support booleans.
    #   Replace the content of this test with something like:
    #     assert {:ok, {true, :Bool, _}} = TE.eval("1 < 1 == 2 > 2")
    #     assert {:ok, {true, :Bool, _}} = TE.eval("1 <= 1 != 2 >= 3")
    test "comparison operators == and != have less precedence than <, >, <=, >=" do
      # Just for now, we test the parser for precedence
      assert {
               :call,
               {:==, {1, 0, 14}},
               [
                 {:call, {:<, {1, 0, 5}}, [{:integer, {1, 0, 1}, 1}, {:integer, {1, 0, 5}, 1}],
                  :kernel},
                 {:call, {:>, {1, 0, 14}}, [{:integer, {1, 0, 10}, 2}, {:integer, {1, 0, 14}, 2}],
                  :kernel}
               ],
               :kernel
             } == TestParser.expression!("1 < 1 == 2 > 2")

      assert {
               :call,
               {:!=, {1, 0, 16}},
               [
                 {:call, {:<=, {1, 0, 6}}, [{:integer, {1, 0, 1}, 1}, {:integer, {1, 0, 6}, 1}],
                  :kernel},
                 {:call, {:>=, {1, 0, 16}},
                  [{:integer, {1, 0, 11}, 2}, {:integer, {1, 0, 16}, 3}], :kernel}
               ],
               :kernel
             } == TestParser.expression!("1 <= 1 != 2 >= 3")

      # Then we test == and != actually work
      assert {:ok, {true, :Bool, _}} = TE.eval("1 == 1")
      assert {:ok, {false, :Bool, _}} = TE.eval("1 != 1")
    end

    test "boolean & has less precedence than == and !=" do
      assert {:ok, {true, :Bool, _}} = TE.eval("1 == 1 & 1 != 2")
      assert {:ok, {false, :Bool, _}} = TE.eval("2 == 1 & 1 != 2")
    end

    test "boolean | has less precedence than &" do
      assert {:ok, {true, :Bool, _}} = TE.eval("true | true & false")
      assert {:ok, {true, :Bool, _}} = TE.eval("false & :true | true")
    end

    test "expressions in parenthesis have higher precedence than anything else" do
      assert {:ok, {1, :Int, _}} = TE.eval("-(-1)")
      assert {:ok, {6, :Int, _}} = TE.eval("(3 - 1) * (1 + 2)")
      assert {:ok, {true, :Bool, _}} = TE.eval("2 >= (1 + 1)")
      assert {:ok, {true, :Bool, _}} = TE.eval("true & (false | true)")
    end
  end

  describe "operators with spaces" do
    # Unary operators' operand doesn't necessarily have to reside on the same line of the operator
    test "both vertical and horizontal space allowed between unary operators and their operand" do
      assert {:ok, {false, :Bool, _}} = TE.eval("!#{TP.space()}true")
      assert {:ok, {-1, :Int, _}} = TE.eval("-#{TP.space()}1")
    end

    # Horizontal space allowed between first operand and binary operator
    # Both vertical and horizontal space allowed between binary operator and second operand
    test "allowed spaces between binary operators and their operands" do
      assert {:ok, {12, :Int, _}} = TE.eval("3#{TP.h_space()}*#{TP.space()}4")
      assert {:ok, {2.0, :Float, _}} = TE.eval("4#{TP.h_space()}/#{TP.space()}2")
      assert {:ok, {7, :Int, _}} = TE.eval("3#{TP.h_space()}+#{TP.space()}4")
      assert {:ok, {1, :Int, _}} = TE.eval("3#{TP.h_space()}-#{TP.space()}2")
      assert {:ok, {true, :Bool, _}} = TE.eval("2#{TP.h_space()}<#{TP.space()}3")
      assert {:ok, {true, :Bool, _}} = TE.eval("2#{TP.h_space()}<=#{TP.space()}3")
      assert {:ok, {true, :Bool, _}} = TE.eval("2#{TP.h_space()}>#{TP.space()}1")
      assert {:ok, {true, :Bool, _}} = TE.eval("2#{TP.h_space()}>=#{TP.space()}1")
      assert {:ok, {true, :Bool, _}} = TE.eval("2#{TP.h_space()}==#{TP.space()}2")
      assert {:ok, {true, :Bool, _}} = TE.eval("2#{TP.h_space()}!=#{TP.space()}1")
      assert {:ok, {true, :Bool, _}} = TE.eval("true#{TP.h_space()}&#{TP.space()}true")
      assert {:ok, {true, :Bool, _}} = TE.eval("false#{TP.h_space()}|#{TP.space()}true")
    end

    # Vertical space forbidden between first operand and binary operator
    test "forbidden vertical space between first operand and binary operator" do
      msg = "expected end of string"

      assert {:error, ^msg, _, _, _, _} = TE.eval("3#{TP.space()}*#{TP.space()}4")
      assert {:error, ^msg, _, _, _, _} = TE.eval("3#{TP.space()}/#{TP.space()}2")
      assert {:error, ^msg, _, _, _, _} = TE.eval("3#{TP.space()}+#{TP.space()}4")
      assert {:error, ^msg, _, _, _, _} = TE.eval("3#{TP.space()}-#{TP.space()}2")
      assert {:error, ^msg, _, _, _, _} = TE.eval("2#{TP.space()}<#{TP.space()}3")
      assert {:error, ^msg, _, _, _, _} = TE.eval("2#{TP.space()}<=#{TP.space()}3")
      assert {:error, ^msg, _, _, _, _} = TE.eval("2#{TP.space()}>#{TP.space()}1")
      assert {:error, ^msg, _, _, _, _} = TE.eval("2#{TP.space()}>=#{TP.space()}1")
      assert {:error, ^msg, _, _, _, _} = TE.eval("2#{TP.space()}==#{TP.space()}2")
      assert {:error, ^msg, _, _, _, _} = TE.eval("2#{TP.space()}!=#{TP.space()}1")
      assert {:error, ^msg, _, _, _, _} = TE.eval("true#{TP.space()}&#{TP.space()}true")
      assert {:error, ^msg, _, _, _, _} = TE.eval("false#{TP.space()}|#{TP.space()}true")
    end

    # Minus is the only operator which is both unary and binary,
    # therefore we make sure is parsed as unary when it appears on new line
    # (actually, also & is both unary and binary, but needs parser refactoring first)
    test "minus operator is parsed as unary (not binary) when on new line" do
      str = """
      fn foo do
        x
        - y
      end
      """

      assert {
               :function,
               [position: {4, 20, 23}],
               {:foo, [], {:type, {1, 0, 6}, :Nothing},
                [
                  {:identifier, {2, 10, 13}, :x},
                  {:call, {:-, {3, 14, 19}}, [{:identifier, {3, 14, 19}, :y}], :kernel}
                ]}
             } == TestParser.function_def!(str)
    end
  end

  describe "arithmetic" do
    test "arithmetic with add and mult" do
      str = """
      2 + 3 * 4
      """

      assert {
               :call,
               {:+, {1, 0, 9}},
               [
                 {:integer, {1, 0, 1}, 2},
                 {:call, {:*, {1, 0, 9}}, [{:integer, {1, 0, 5}, 3}, {:integer, {1, 0, 9}, 4}],
                  :kernel}
               ],
               :kernel
             } == TestParser.expression!(str)
    end

    test "unary -" do
      assert {
               :call,
               {:-, {1, 0, 2}},
               [{:integer, {1, 0, 2}, 5}],
               :kernel
             } == TestParser.expression!("-5")
    end

    test "unary - has higher precedence than other arithmetic operators" do
      str = """
      11 + -5 - 10 * -1 / -2
      """

      assert {
               :call,
               {:-, {1, 0, 22}},
               [
                 {:call, {:+, {1, 0, 22}},
                  [
                    {:integer, {1, 0, 2}, 11},
                    {:call, {:-, {1, 0, 7}}, [{:integer, {1, 0, 7}, 5}], :kernel}
                  ], :kernel},
                 {:call, {:/, {1, 0, 22}},
                  [
                    {:call, {:*, {1, 0, 22}},
                     [
                       {:integer, {1, 0, 12}, 10},
                       {:call, {:-, {1, 0, 17}}, [{:integer, {1, 0, 17}, 1}], :kernel}
                     ], :kernel},
                    {:call, {:-, {1, 0, 22}}, [{:integer, {1, 0, 22}, 2}], :kernel}
                  ], :kernel}
               ],
               :kernel
             } == TestParser.expression!(str)
    end

    test "+ and - are parsed as unary operators when on new line" do
      str = """
      fn foo do
        x
        - y
      end
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.function_def(str)

      assert result == [
               {
                 :function,
                 [position: {4, 20, 23}],
                 {:foo, [], {:type, {1, 0, 6}, :Nothing},
                  [
                    {:identifier, {2, 10, 13}, :x},
                    {:call, {:-, {3, 14, 19}}, [{:identifier, {3, 14, 19}, :y}], :kernel}
                  ]}
               }
             ]
    end

    test "+ and - are parsed as binary operators when on the same line of the first operand" do
      str = """
      fn foo do
        x -
        y
      end
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.function_def(str)

      assert result == [
               {
                 :function,
                 [position: {4, 20, 23}],
                 {:foo, [], {:type, {1, 0, 6}, :Nothing},
                  [
                    {:call, {:-, {3, 16, 19}},
                     [
                       {:identifier, {2, 10, 13}, :x},
                       {:identifier, {3, 16, 19}, :y}
                     ], :kernel}
                  ]}
               }
             ]
    end

    test "add/sub has less precedence than mult/div" do
      str = """
      10 + 20 * 30 - 40 / 50
      """

      assert {
               :call,
               {:-, {1, 0, 22}},
               [
                 {:call, {:+, {1, 0, 22}},
                  [
                    {:integer, {1, 0, 2}, 10},
                    {:call, {:*, {1, 0, 12}},
                     [{:integer, {1, 0, 7}, 20}, {:integer, {1, 0, 12}, 30}], :kernel}
                  ], :kernel},
                 {:call, {:/, {1, 0, 22}},
                  [{:integer, {1, 0, 17}, 40}, {:integer, {1, 0, 22}, 50}], :kernel}
               ],
               :kernel
             } == TestParser.expression!(str)
    end

    test "grouping using parens" do
      str = """
      (10 + 20) * (30 - 40) / 50
      """

      assert {
               :call,
               {:/, {1, 0, 26}},
               [
                 {
                   :call,
                   {:*, {1, 0, 26}},
                   [
                     {:call, {:+, {1, 0, 8}},
                      [{:integer, {1, 0, 3}, 10}, {:integer, {1, 0, 8}, 20}], :kernel},
                     {:call, {:-, {1, 0, 20}},
                      [{:integer, {1, 0, 15}, 30}, {:integer, {1, 0, 20}, 40}], :kernel}
                   ],
                   :kernel
                 },
                 {:integer, {1, 0, 26}, 50}
               ],
               :kernel
             } == TestParser.expression!(str)
    end
  end

  describe "function calls" do
    test "local function call without args" do
      str = """
      my_func()
      """

      assert {:call, {:my_func, {1, 0, 9}}, [], nil} == TestParser.expression!(str)
    end

    test "local function call with args" do
      str = """
      my_func(x, 123)
      """

      args = [
        {:identifier, {1, 0, 9}, :x},
        {:integer, {1, 0, 14}, 123}
      ]

      assert {:call, {:my_func, {1, 0, 15}}, args, nil} == TestParser.expression!(str)
    end

    test "remote function call with args" do
      str = """
      my_module.my_func(x, 123)
      """

      args = [
        {:identifier, {1, 0, 19}, :x},
        {:integer, {1, 0, 24}, 123}
      ]

      assert {:call, {:my_func, {1, 0, 25}}, args, :my_module} == TestParser.expression!(str)
    end

    test "function calls with another function call as arg" do
      str = """
      foo(x, bar(y))
      """

      args = [
        {:identifier, {1, 0, 5}, :x},
        {:call, {:bar, {1, 0, 13}}, [{:identifier, {1, 0, 12}, :y}], nil}
      ]

      assert {:call, {:foo, {1, 0, 14}}, args, nil} == TestParser.expression!(str)
    end
  end

  describe "function definition" do
    test "without args or type" do
      str = """
      fn foo do
        123
      end
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.function_def(str)

      assert result == [
               {:function, [position: {3, 16, 19}],
                {:foo, [], {:type, {1, 0, 6}, :Nothing}, [{:integer, {2, 10, 15}, 123}]}}
             ]
    end

    test "with return type Int" do
      str = """
      fn foo : Int do
        123
      end
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.function_def(str)

      assert result == [
               {:function, [position: {3, 22, 25}],
                {:foo, [], {:type, {1, 0, 12}, :Int}, [{:integer, {2, 16, 21}, 123}]}}
             ]
    end

    test "with return type :ok" do
      str = """
      fn foo : :ok do
        123
      end
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.function_def(str)

      assert result == [
               {:function, [position: {3, 22, 25}],
                {:foo, [], {:type, {1, 0, 12}, :ok}, [{:integer, {2, 16, 21}, 123}]}}
             ]
    end

    test "with type params" do
      str = """
      fn foo(a: List(List(List(String)))) : List(Nothing) do
        x
      end
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.function_def(str)

      assert result == [
               {:function, [position: {3, 59, 62}],
                {:foo,
                 [
                   {{:identifier, {1, 0, 8}, :a},
                    {:type, {1, 0, 34}, %T.List{type: %T.List{type: %T.List{type: :String}}}}}
                 ], {:type, {1, 0, 51}, %T.List{type: :Nothing}},
                 [{:identifier, {2, 55, 58}, :x}]}}
             ]
    end

    test "with args" do
      str = """
      fn foo(x: Int, y: Int) : Int do
        x + y
      end
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.function_def(str)

      assert result == [
               {:function, [position: {3, 40, 43}],
                {:foo,
                 [
                   {{:identifier, {1, 0, 8}, :x}, {:type, {1, 0, 13}, :Int}},
                   {{:identifier, {1, 0, 16}, :y}, {:type, {1, 0, 21}, :Int}}
                 ], {:type, {1, 0, 28}, :Int},
                 [
                   {:call, {:+, {2, 32, 39}},
                    [{:identifier, {2, 32, 35}, :x}, {:identifier, {2, 32, 39}, :y}], :kernel}
                 ]}}
             ]
    end

    test "with union types" do
      code = """
      fn foo(a: Int | Float, b: Nothing) : :ok | {:error, String} do
        if true do
          :ok
        else
          {:error, "not ok"}
        end
      end
      """

      assert {:ok,
              [
                {:function, [position: {7, 120, 123}],
                 {:foo,
                  [
                    {{:identifier, {1, 0, 8}, :a},
                     {:type, {1, 0, 21}, %T.Union{types: [:Int, :Float]}}},
                    {{:identifier, {1, 0, 24}, :b}, {:type, {1, 0, 33}, :Nothing}}
                  ],
                  {:type, {1, 0, 59},
                   %T.Union{
                     types: [
                       :ok,
                       %T.Tuple{elements: [:error, :String]}
                     ]
                   }},
                  [
                    {{:if, {6, 114, 119}}, {:boolean, {2, 63, 72}, true},
                     [{:atom, {3, 76, 83}, :ok}],
                     [
                       {:tuple, {5, 91, 113},
                        [{:atom, {5, 91, 102}, :error}, {:string, {5, 91, 112}, ["not ok"]}]}
                     ]}
                  ]}}
              ], "\n", %{}, {7, 120}, 123} = TestParser.function_def(code)
    end
  end

  describe "if-else expression" do
    test "simple if-else" do
      str = """
      if true do
        a = 1
        b = 2
      else
        c = 3
      end
      """

      assert {
               {:if, {6, 40, 43}},
               parsed_condition,
               parsed_if_block,
               parsed_else_block
             } = TestParser.expression!(str)

      assert {:boolean, {1, 0, 7}, true} = parsed_condition

      assert [
               {{:=, {2, 11, 18}}, {:identifier, {2, 11, 14}, :a}, {:integer, {2, 11, 18}, 1}},
               {{:=, {3, 19, 26}}, {:identifier, {3, 19, 22}, :b}, {:integer, {3, 19, 26}, 2}}
             ] = parsed_if_block

      assert [
               {{:=, {5, 32, 39}}, {:identifier, {5, 32, 35}, :c}, {:integer, {5, 32, 39}, 3}}
             ] = parsed_else_block
    end
  end

  describe "match expression" do
    test "simple match" do
      str = """
      x = 1
      """

      assert {{:=, {1, 0, 5}}, {:identifier, {1, 0, 1}, :x}, {:integer, {1, 0, 5}, 1}} ==
               TestParser.expression!(str)
    end

    test "multiple match" do
      str = """
      x = y = 1
      """

      assert {
               {:=, {1, 0, 9}},
               {:identifier, {1, 0, 1}, :x},
               {
                 {:=, {1, 0, 9}},
                 {:identifier, {1, 0, 5}, :y},
                 {:integer, {1, 0, 9}, 1}
               }
             } == TestParser.expression!(str)
    end

    test "errors when non match exps come on the left of the match" do
      str = """
      x + y = 1
      """

      assert {:error, "expected end of string", "= 1\n", _, _, _} = TestParser.expression(str)
    end

    test "match exps can exist as a whole exp" do
      str = """
      1 + (x = 2)
      """

      assert {:call, {:+, {1, 0, 11}},
              [
                {:integer, {1, 0, 1}, 1},
                {
                  {:=, {1, 0, 10}},
                  {:identifier, {1, 0, 6}, :x},
                  {:integer, {1, 0, 10}, 2}
                }
              ], :kernel} == TestParser.expression!(str)
    end
  end

  describe "strings" do
    test "parses a simple string" do
      str = """
      "Hello world"
      """

      assert {:string, {1, 0, 13}, ["Hello world"]} == TestParser.expression!(str)
    end

    test "parses a string with escaped double quotes" do
      str = """
      "Hello \\\"world\\\""
      """

      assert {:string, {1, 0, 17}, ["Hello \\\"world\\\""]} == TestParser.expression!(str)
    end

    test "parses interpolated string" do
      str = ~S"""
      "Hello #{world}"
      """

      assert {:string, {1, 0, 16}, ["Hello ", {:identifier, {1, 0, 14}, :world}]} ==
               TestParser.expression!(str)
    end

    test "parses multiple interpolations" do
      str = ~S"""
      "#{hello} #{"World"}"
      """

      assert {
               :string,
               {1, 0, 21},
               [
                 {:identifier, {1, 0, 8}, :hello},
                 " ",
                 {:string, {1, 0, 19}, ["World"]}
               ]
             } == TestParser.expression!(str)
    end
  end

  describe "list" do
    test "parses empty list" do
      str = """
      []
      """

      assert {:list, {1, 0, 2}, []} == TestParser.expression!(str)
    end

    test "parses list with one element" do
      str = """
      [1]
      """

      assert {:list, {1, 0, 3}, [{:integer, {1, 0, 2}, 1}]} == TestParser.expression!(str)
    end

    test "parses list with multiple elements" do
      str = """
      [1, 2, 3]
      """

      assert {:list, {1, 0, 9},
              [
                {:integer, {1, 0, 2}, 1},
                {:integer, {1, 0, 5}, 2},
                {:integer, {1, 0, 8}, 3}
              ]} == TestParser.expression!(str)
    end

    test "parses list with match exps" do
      str = """
      [a = 1, 2, 3]
      """

      assert {:list, {1, 0, 13},
              [
                {{:=, {1, 0, 6}}, {:identifier, {1, 0, 2}, :a}, {:integer, {1, 0, 6}, 1}},
                {:integer, {1, 0, 9}, 2},
                {:integer, {1, 0, 12}, 3}
              ]} == TestParser.expression!(str)
    end
  end

  describe "records" do
    test "empty records are invalid" do
      str = """
      {}
      """

      assert {:error, _, "{}\n", %{}, {1, 0}, 0} = TestParser.expression(str)
    end

    test "parses a record" do
      str = """
      {hello: "World", foo: 123}
      """

      assert {:record, {1, 0, 26}, nil,
              [
                {{:identifier, {1, 0, 6}, :hello}, {:string, {1, 0, 15}, ["World"]}},
                {{:identifier, {1, 0, 20}, :foo}, {:integer, {1, 0, 25}, 123}}
              ]} == TestParser.expression!(str)
    end
  end

  describe "map" do
    test "parses map with key values" do
      str = """
      {"a" => 1}
      """

      result = TestParser.expression!(str)

      assert result ==
               {:map, {1, 0, 10}, [{{:string, {1, 0, 4}, ["a"]}, {:integer, {1, 0, 9}, 1}}]}
    end

    test "parses map with complex expression" do
      str = """
      {[1+1, 2] => {"1" => {1, 2, 3}}}
      """

      result = TestParser.expression!(str)

      assert result ==
               {
                 :map,
                 {1, 0, 32},
                 [
                   {
                     {:list, {1, 0, 9},
                      [
                        {:call, {:+, {1, 0, 5}},
                         [{:integer, {1, 0, 3}, 1}, {:integer, {1, 0, 5}, 1}], :kernel},
                        {:integer, {1, 0, 8}, 2}
                      ]},
                     {:map, {1, 0, 31},
                      [
                        {{:string, {1, 0, 17}, ["1"]},
                         {:tuple, {1, 0, 30},
                          [
                            {:integer, {1, 0, 23}, 1},
                            {:integer, {1, 0, 26}, 2},
                            {:integer, {1, 0, 29}, 3}
                          ]}}
                      ]}
                   }
                 ]
               }

      str = """
      {true & false => false}
      """

      result = TestParser.expression!(str)

      assert result ==
               {:map, {1, 0, 23},
                [
                  {{:call, {:&, {1, 0, 13}},
                    [{:boolean, {1, 0, 5}, true}, {:boolean, {1, 0, 13}, false}], :kernel},
                   {:boolean, {1, 0, 22}, false}}
                ]}
    end

    test "parses map with function as key-values" do
      str = """
      {foo(1, 2) => bar(true)}
      """

      result = TestParser.expression!(str)

      assert result ==
               {:map, {1, 0, 24},
                [
                  {{:call, {:foo, {1, 0, 10}},
                    [{:integer, {1, 0, 6}, 1}, {:integer, {1, 0, 9}, 2}], nil},
                   {:call, {:bar, {1, 0, 23}}, [{:boolean, {1, 0, 22}, true}], nil}}
                ]}

      str = """
      {&foo.bar => jar(true)}
      """

      result = TestParser.expression!(str)

      assert result ==
               {
                 :map,
                 {1, 0, 23},
                 [
                   {
                     {:function_ref, {1, 0, 9}, {:foo, :bar, []}},
                     {:call, {:jar, {1, 0, 22}}, [{:boolean, {1, 0, 21}, true}], nil}
                   }
                 ]
               }
    end
  end

  describe "tuple" do
    test "parses tuple with one element" do
      str = """
      {1}
      """

      assert {:tuple, {1, 0, 3}, [{:integer, {1, 0, 2}, 1}]} == TestParser.expression!(str)
    end

    test "parses tuple with multiple elements" do
      str = """
      {1, 2, 3}
      """

      assert {:tuple, {1, 0, 9},
              [
                {:integer, {1, 0, 2}, 1},
                {:integer, {1, 0, 5}, 2},
                {:integer, {1, 0, 8}, 3}
              ]} == TestParser.expression!(str)
    end

    test "parses tuple with match exps" do
      str = """
      {a = 1, 2, 3}
      """

      assert {:tuple, {1, 0, 13},
              [
                {{:=, {1, 0, 6}}, {:identifier, {1, 0, 2}, :a}, {:integer, {1, 0, 6}, 1}},
                {:integer, {1, 0, 9}, 2},
                {:integer, {1, 0, 12}, 3}
              ]} == TestParser.expression!(str)
    end
  end

  describe "types" do
    test "types with no args" do
      str = "Int"

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.type_str(str)

      assert result == [{:type, {1, 0, 3}, :Int}]
    end

    test "parses types with an arg" do
      str = "List(Int)"

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.type_str(str)

      assert result == [{:type, {1, 0, 9}, %T.List{type: :Int}}]
    end

    test "parses types with nested args" do
      str = "List(List(String))"

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.type_str(str)

      assert result == [{:type, {1, 0, 18}, %T.List{type: %T.List{type: :String}}}]
    end

    test "parses function type with no args" do
      str = "Fn(-> Int)"

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.type_str(str)

      assert result == [
               {:type, {1, 0, 10},
                %T.FunctionRef{
                  arg_types: [],
                  return_type: :Int
                }}
             ]
    end

    test "parses function type with args" do
      str = "Fn(Int, Int -> Int)"

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.type_str(str)

      assert result == [
               {:type, {1, 0, 19},
                %T.FunctionRef{
                  arg_types: [:Int, :Int],
                  return_type: :Int
                }}
             ]
    end

    test "record type" do
      str = "{foo: Int, bar: String}"

      assert {:type, {1, 0, 23}, "{foo:Int,bar:String}"} == TestParser.type_str!(str)
    end

    test "atom type" do
      str = ":foo"

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.type_str(str)
      assert result == [{:type, {1, 0, 4}, :foo}]
    end

    test "list of atom" do
      str = "List(:foo)"

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.type_str(str)
      assert result == [{:type, {1, 0, 10}, %T.List{type: :foo}}]
    end
  end

  describe "function reference" do
    test "parses a function ref with no args" do
      str = """
      &foo
      """

      result = TestParser.expression!(str)

      assert result ==
               {:function_ref, {1, 0, 4}, {nil, :foo, []}}
    end

    test "parses a remote function ref with no args" do
      str = """
      &foo.bar
      """

      result = TestParser.expression!(str)

      assert result ==
               {:function_ref, {1, 0, 8}, {:foo, :bar, []}}
    end

    test "parses a function ref with arg types" do
      str = """
      &foo.bar(Int, Int)
      """

      result = TestParser.expression!(str)

      assert result ==
               {:function_ref, {1, 0, 18}, {:foo, :bar, [:Int, :Int]}}
    end
  end

  describe "comments" do
    test "before function def" do
      str = """
      # This is a comment
      fn foo do
        123
      end
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.function_def(str)

      assert result == [
               {:function, [position: {4, 36, 39}],
                {:foo, [], {:type, {2, 20, 26}, :Nothing}, [{:integer, {3, 30, 35}, 123}]}}
             ]
    end

    test "At end of line" do
      str = """
      fn foo do # Comment 1
        123 # Comment 2
      end # Comment 3
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.function_def(str)

      assert result == [
               {:function, [position: {3, 40, 43}],
                {:foo, [], {:type, {1, 0, 6}, :Nothing}, [{:integer, {2, 22, 27}, 123}]}}
             ]
    end

    test "Can't appear in between characters" do
      str = """
      fn foo #Comment do
        123
      end
      """

      assert {:error, _, _, _, _, _} = TestParser.function_def(str)
    end

    test "Strings can have # in them" do
      str = """
      fn foo do
        "foo#bar"
      end
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = TestParser.function_def(str)

      assert result == [
               {:function, [position: {3, 22, 25}],
                {:foo, [], {:type, {1, 0, 6}, :Nothing}, [{:string, {2, 10, 21}, ["foo#bar"]}]}}
             ]
    end
  end

  describe "call using function reference" do
    test "using identifier" do
      str = "foo.(x, y)"

      args = [
        {:identifier, {1, 0, 6}, :x},
        {:identifier, {1, 0, 9}, :y}
      ]

      assert {:call, {{:identifier, {1, 0, 3}, :foo}, {1, 0, 10}}, args} ==
               TestParser.expression!(str)
    end

    test "using function call" do
      str = "foo().(x, y)"

      args = [
        {:identifier, {1, 0, 8}, :x},
        {:identifier, {1, 0, 11}, :y}
      ]

      exp = {:call, {:foo, {1, 0, 5}}, [], nil}

      assert {:call, {exp, {1, 0, 12}}, args} == TestParser.expression!(str)
    end

    test "using literal expression fails" do
      str = "123.(x, y)"

      assert {:error, _, _, _, _, _} = TestParser.expression(str)
    end
  end

  describe "logical operators" do
    test "supports negation" do
      assert {:call, {:!, _}, [{:boolean, _, true}], _kernel} = TestParser.expression!("!true")
    end

    test "supports negation with more complex expressions" do
      {
        :call,
        {:!, _},
        [
          {:call, {:|, _}, [{:boolean, _, true}, {:boolean, _, false}], :kernel}
        ],
        :kernel
      } = TestParser.expression!("!(true | false)")
    end

    test "simple usage" do
      str = "false | true"

      assert {:call, {:|, _},
              [
                {:boolean, _, false},
                {:boolean, _, true}
              ], :kernel} = TestParser.expression!(str)
    end

    test "more complex expressions" do
      str = "true & (false | :true)"

      assert {
               :call,
               {:&, _},
               [
                 {:boolean, _, true},
                 {:call, {:|, _}, [{:boolean, _, false}, {:boolean, _, true}], :kernel}
               ],
               :kernel
             } = TestParser.expression!(str)
    end
  end

  describe "expression delimiter" do
    test "cannot have two assignments in the same line" do
      str = "x = 1 y = 2"

      assert {:error, _, _, _, _, _} = TestParser.exps(str)
    end

    test "cannot have two variables in the same line" do
      str = "foo bar"
      assert {:error, _, _, _, _, _} = TestParser.exps(str)
    end

    test "can have expressions in multiple lines" do
      str = """
      x = 1
      y = 2
      """

      assert {:ok, [_, _], _, _, _, _} = TestParser.exps(str)
    end

    test "can have expressions separated by ;" do
      str = """
      x = 1; y=2
      """

      assert {:ok, [_, _], _, _, _, _} = TestParser.exps(str)
    end

    test "can have a single expression split across multiple lines" do
      str = """
      x =
        123 +
          345
      """

      assert {:ok, [_], _, _, _, _} = TestParser.exps(str)

      str = """
      x = foo &
        bar
      """

      assert {:ok, [_], _, _, _, _} = TestParser.exps(str)
    end

    test "function ref on new line" do
      str = """
      x = foo
        &bar
      """

      assert {:ok, [_, {:function_ref, _, _}], _, _, _, _} = TestParser.exps(str)
    end

    # TODO: This actually looks cleaner, so we may eventually allow this
    # by adding more fine grained rules to our parser.
    test "| on newline is an error" do
      str = """
      x = foo
        | bar
        | baz
      """

      assert {:error, _, _, _, _, _} = TestParser.exps(str)
    end

    test "| on same line is ok" do
      str = """
      x = foo |
        bar |
        baz
      """

      assert {:ok, [_], _, _, _, _} = TestParser.exps(str)
    end

    test "= on newline is an error" do
      str = """
      x
      = 123
      """

      assert {:error, _, _, _, _, _} = TestParser.exps(str)
    end
  end
end
