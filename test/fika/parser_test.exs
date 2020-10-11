defmodule Fika.ParserTest do
  use ExUnit.Case
  alias Fika.Parser

  test "integer" do
    str = """
    123
    """

    {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)
    assert result == [{:integer, {1, 0, 3}, 123}]
  end

  describe "boolean" do
    test "true" do
      str = "true"

      result = Parser.expression!(str)
      assert result == {:boolean, {1, 0, 4}, true}
    end

    test "false" do
      str = "false"

      result = Parser.expression!(str)
      assert result == {:boolean, {1, 0, 5}, false}
    end
  end

  describe "atom" do
    test "parses multi-char atoms" do
      atom = :foobar
      str = ":#{atom}"

      assert Parser.expression!(str) == {:atom, {1, 0, 7}, atom}
    end
  end

  describe "arithmetic" do
    test "arithmetic with add and mult" do
      str = """
      2 + 3 * 4
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [
               {
                 :call,
                 {:+, {1, 0, 9}},
                 [
                   {:integer, {1, 0, 1}, 2},
                   {:call, {:*, {1, 0, 9}}, [{:integer, {1, 0, 5}, 3}, {:integer, {1, 0, 9}, 4}],
                    :kernel}
                 ],
                 :kernel
               }
             ]
    end

    test "add/sub has less precedence than mult/div" do
      str = """
      10 + 20 * 30 - 40 / 50
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [
               {
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
               }
             ]
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
               }
             ]
    end
  end

  describe "function calls" do
    test "local function call without args" do
      str = """
      my_func()
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)
      assert result == [{:call, {:my_func, {1, 0, 9}}, [], nil}]
    end

    test "local function call with args" do
      str = """
      my_func(x, 123)
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      args = [
        {:identifier, {1, 0, 9}, :x},
        {:integer, {1, 0, 14}, 123}
      ]

      assert result == [{:call, {:my_func, {1, 0, 15}}, args, nil}]
    end

    test "remote function call with args" do
      str = """
      my_module.my_func(x, 123)
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      args = [
        {:identifier, {1, 0, 19}, :x},
        {:integer, {1, 0, 24}, 123}
      ]

      assert result == [{:call, {:my_func, {1, 0, 25}}, args, :my_module}]
    end

    test "function calls with another function call as arg" do
      str = """
      foo(x, bar(y))
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      args = [
        {:identifier, {1, 0, 5}, :x},
        {:call, {:bar, {1, 0, 13}}, [{:identifier, {1, 0, 12}, :y}], nil}
      ]

      assert result == [{:call, {:foo, {1, 0, 14}}, args, nil}]
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

    test "with return type Int" do
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

    test "with return type :ok" do
      str = """
      fn foo : :ok do
        123
      end
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.function_def(str)

      assert result == [
               {:function, [position: {3, 22, 25}],
                {:foo, [], {:type, {1, 0, 12}, ":ok"}, [{:integer, {2, 16, 21}, 123}]}}
             ]
    end

    test "with type params" do
      str = """
      fn foo(a: List(String)) : List(Int) do
        x
      end
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.function_def(str)

      assert result == [
               {:function, [position: {3, 43, 46}],
                {:foo, [{{:identifier, {1, 0, 8}, :a}, {:type, {1, 0, 22}, "List(String)"}}],
                 {:type, {1, 0, 35}, "List(Int)"}, [{:identifier, {2, 39, 42}, :x}]}}
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
                 ], {:type, {1, 0, 28}, "Int"},
                 [
                   {:call, {:+, {2, 32, 39}},
                    [{:identifier, {2, 32, 35}, :x}, {:identifier, {2, 32, 39}, :y}], :kernel}
                 ]}}
             ]
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
             } = Parser.expression!(str)

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

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [
               {{:=, {1, 0, 5}}, {:identifier, {1, 0, 1}, :x}, {:integer, {1, 0, 5}, 1}}
             ]
    end

    test "multiple match" do
      str = """
      x = y = 1
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [
               {
                 {:=, {1, 0, 9}},
                 {:identifier, {1, 0, 1}, :x},
                 {
                   {:=, {1, 0, 9}},
                   {:identifier, {1, 0, 5}, :y},
                   {:integer, {1, 0, 9}, 1}
                 }
               }
             ]
    end

    test "errors when non match exps come on the left of the match" do
      str = """
      x + y = 1
      """

      assert {:error, "expected end of string", "= 1\n", _, _, _} = Parser.expression(str)
    end

    test "match exps can exist as a whole exp" do
      str = """
      1 + (x = 2)
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [
               {:call, {:+, {1, 0, 11}},
                [
                  {:integer, {1, 0, 1}, 1},
                  {
                    {:=, {1, 0, 10}},
                    {:identifier, {1, 0, 6}, :x},
                    {:integer, {1, 0, 10}, 2}
                  }
                ], :kernel}
             ]
    end
  end

  describe "strings" do
    test "parses a simple string" do
      str = """
      "Hello world"
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [{:string, {1, 0, 13}, "Hello world"}]
    end

    test "parses a string with escaped double quotes" do
      str = """
      "Hello \\\"world\\\""
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [{:string, {1, 0, 17}, "Hello \\\"world\\\""}]
    end
  end

  describe "list" do
    test "parses empty list" do
      str = """
      []
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)
      assert result == [{:list, {1, 0, 2}, []}]
    end

    test "parses list with one element" do
      str = """
      [1]
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)
      assert result == [{:list, {1, 0, 3}, [{:integer, {1, 0, 2}, 1}]}]
    end

    test "parses list with multiple elements" do
      str = """
      [1, 2, 3]
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [
               {:list, {1, 0, 9},
                [
                  {:integer, {1, 0, 2}, 1},
                  {:integer, {1, 0, 5}, 2},
                  {:integer, {1, 0, 8}, 3}
                ]}
             ]
    end

    test "parses list with match exps" do
      str = """
      [a = 1, 2, 3]
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [
               {:list, {1, 0, 13},
                [
                  {{:=, {1, 0, 6}}, {:identifier, {1, 0, 2}, :a}, {:integer, {1, 0, 6}, 1}},
                  {:integer, {1, 0, 9}, 2},
                  {:integer, {1, 0, 12}, 3}
                ]}
             ]
    end
  end

  describe "records" do
    test "empty records are invalid" do
      str = """
      {}
      """

      assert {:error, _, "{}\n", %{}, {1, 0}, 0} = Parser.expression(str)
    end

    test "parses a record" do
      str = """
      {hello: "World", foo: 123}
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [
               {:record, {1, 0, 26}, nil,
                [
                  {{:identifier, {1, 0, 6}, :hello}, {:string, {1, 0, 15}, "World"}},
                  {{:identifier, {1, 0, 20}, :foo}, {:integer, {1, 0, 25}, 123}}
                ]}
             ]
    end
  end

  describe "tuple" do
    test "parses tuple with one element" do
      str = """
      {1}
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)
      assert result == [{:tuple, {1, 0, 3}, [{:integer, {1, 0, 2}, 1}]}]
    end

    test "parses tuple with multiple elements" do
      str = """
      {1, 2, 3}
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [
               {:tuple, {1, 0, 9},
                [
                  {:integer, {1, 0, 2}, 1},
                  {:integer, {1, 0, 5}, 2},
                  {:integer, {1, 0, 8}, 3}
                ]}
             ]
    end

    test "parses tuple with match exps" do
      str = """
      {a = 1, 2, 3}
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.expression(str)

      assert result == [
               {:tuple, {1, 0, 13},
                [
                  {{:=, {1, 0, 6}}, {:identifier, {1, 0, 2}, :a}, {:integer, {1, 0, 6}, 1}},
                  {:integer, {1, 0, 9}, 2},
                  {:integer, {1, 0, 12}, 3}
                ]}
             ]
    end
  end

  describe "types" do
    test "types with no args" do
      str = "Int"

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.type_str(str)

      assert result == [{:type, {1, 0, 3}, "Int"}]
    end

    test "parses types with an arg" do
      str = "List(Int)"

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.type_str(str)

      assert result == [{:type, {1, 0, 9}, "List(Int)"}]
    end

    test "parses types with nested args" do
      str = "List(List(String))"

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.type_str(str)

      assert result == [{:type, {1, 0, 18}, "List(List(String))"}]
    end

    test "parses function type with no args" do
      str = "Fn(-> Int)"

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.type_str(str)

      assert result == [{:type, {1, 0, 10}, "Fn(->Int)"}]
    end

    test "parses function type with args" do
      str = "Fn(Int, Int -> Int)"

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.type_str(str)

      assert result == [{:type, {1, 0, 19}, "Fn(Int,Int->Int)"}]
    end

    test "record type" do
      str = "{foo: Int, bar: String}"

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.type_str(str)
      assert result == [{:type, {1, 0, 23}, "{foo:Int,bar:String}"}]
    end

    test "atom type" do
      str = ":foo"

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.type_str(str)
      assert result == [{:type, {1, 0, 4}, ":foo"}]
    end

    test "list of atom" do
      str = "List(:foo)"

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.type_str(str)
      assert result == [{:type, {1, 0, 10}, "List(:foo)"}]
    end
  end

  describe "function reference" do
    test "parses a function ref with no args" do
      str = """
      &foo
      """

      result = Parser.expression!(str)

      assert result == {:function_ref, {1, 0, 4}, {nil, :foo, []}}
    end

    test "parses a remote function ref with no args" do
      str = """
      &foo.bar
      """

      result = Parser.expression!(str)

      assert result ==
               {:function_ref, {1, 0, 8},
                {
                  :foo,
                  :bar,
                  []
                }}
    end

    test "parses a function ref with arg types" do
      str = """
      &foo.bar(Int, Int)
      """

      result = Parser.expression!(str)

      assert result ==
               {:function_ref, {1, 0, 18},
                {
                  :foo,
                  :bar,
                  [
                    "Int",
                    "Int"
                  ]
                }}
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

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.function_def(str)

      assert result == [
               {:function, [position: {4, 36, 39}],
                {:foo, [], {:type, {2, 20, 26}, "Nothing"}, [{:integer, {3, 30, 35}, 123}]}}
             ]
    end

    test "At end of line" do
      str = """
      fn foo do # Comment 1
        123 # Comment 2
      end # Comment 3
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.function_def(str)

      assert result == [
               {:function, [position: {3, 40, 43}],
                {:foo, [], {:type, {1, 0, 6}, "Nothing"}, [{:integer, {2, 22, 27}, 123}]}}
             ]
    end

    test "Can't appear in between characters" do
      str = """
      fn foo #Comment do
        123
      end
      """

      assert {:error, _error, _rest, _context, _line, _byte_offset} = Parser.function_def(str)
    end

    test "Strings can have # in them" do
      str = """
      fn foo do
        "foo#bar"
      end
      """

      {:ok, result, _rest, _context, _line, _byte_offset} = Parser.function_def(str)

      assert result == [
               {:function, [position: {3, 22, 25}],
                {:foo, [], {:type, {1, 0, 6}, "Nothing"}, [{:string, {2, 10, 21}, "foo#bar"}]}}
             ]
    end
  end

  describe "call using function reference" do
    test "using identifier" do
      str = "foo.(x, y)"
      result = Parser.expression!(str)

      args = [
        {:identifier, {1, 0, 6}, :x},
        {:identifier, {1, 0, 9}, :y}
      ]

      assert result == {:call, {{:identifier, {1, 0, 3}, :foo}, {1, 0, 10}}, args}
    end

    test "using function call" do
      str = "foo().(x, y)"
      result = Parser.expression!(str)

      args = [
        {:identifier, {1, 0, 8}, :x},
        {:identifier, {1, 0, 11}, :y}
      ]

      exp = {:call, {:foo, {1, 0, 5}}, [], nil}
      assert result == {:call, {exp, {1, 0, 12}}, args}
    end

    test "using literal expression fails" do
      str = "123.(x, y)"
      assert {:error, _, _, _, _, _} = Parser.expression(str)
    end
  end

  describe "logic operators" do
    test "supports negation" do
      assert {:call, {:!, _}, [{:boolean, _, true}], kernel} = Parser.expression!("!true")
    end

    test "supports negation with more complex expressions" do
      {
        :call,
        {:!, _},
        [
          {:call, {:||, _}, [{:boolean, _, true}, {:boolean, _, false}], :kernel}
        ],
        :kernel
      } = Parser.expression!("!(true || false)")
    end

    test "simple usage" do
      str = "false || true"
      result = Parser.expression!(str)

      assert {:call, {:||, _},
              [
                {:boolean, _, false},
                {:boolean, _, true}
              ], :kernel} = result
    end

    test "more complex expressions" do
      str = "true && (false || :true)"
      result = Parser.expression!(str)

      assert {
               :call,
               {:&&, _},
               [
                 {:boolean, _, true},
                 {:call, {:||, _}, [{:boolean, _, false}, {:boolean, _, true}], :kernel}
               ],
               :kernel
             } = result
    end
  end
end
