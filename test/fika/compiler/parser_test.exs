defmodule Fika.Compiler.ParserTest do
  use ExUnit.Case, async: true

  alias Fika.Compiler.TypeChecker.Types, as: T
  alias Fika.Compiler.Parser

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
                  "fika/kernel"}
               ],
               "fika/kernel"
             } == TestParser.expression!(str)
    end

    test "unary -" do
      assert {
               :call,
               {:-, {1, 0, 2}},
               [{:integer, {1, 0, 2}, 5}],
               "fika/kernel"
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
                    {:call, {:-, {1, 0, 7}}, [{:integer, {1, 0, 7}, 5}], "fika/kernel"}
                  ], "fika/kernel"},
                 {:call, {:/, {1, 0, 22}},
                  [
                    {:call, {:*, {1, 0, 22}},
                     [
                       {:integer, {1, 0, 12}, 10},
                       {:call, {:-, {1, 0, 17}}, [{:integer, {1, 0, 17}, 1}], "fika/kernel"}
                     ], "fika/kernel"},
                    {:call, {:-, {1, 0, 22}}, [{:integer, {1, 0, 22}, 2}], "fika/kernel"}
                  ], "fika/kernel"}
               ],
               "fika/kernel"
             } == TestParser.expression!(str)
    end

    test "+ and - are parsed as unary operators when on new line" do
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
                  {:call, {:-, {3, 14, 19}}, [{:identifier, {3, 14, 19}, :y}], "fika/kernel"}
                ]}
             } ==
               TestParser.function_def!(str)
    end

    test "+ and - are parsed as binary operators when on the same line of the first operand" do
      str = """
      fn foo do
        x -
        y
      end
      """

      assert {
               :function,
               [position: {4, 20, 23}],
               {:foo, [], {:type, {1, 0, 6}, :Nothing},
                [
                  {:call, {:-, {3, 16, 19}},
                   [
                     {:identifier, {2, 10, 13}, :x},
                     {:identifier, {3, 16, 19}, :y}
                   ], "fika/kernel"}
                ]}
             } ==
               TestParser.function_def!(str)
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
                     [{:integer, {1, 0, 7}, 20}, {:integer, {1, 0, 12}, 30}], "fika/kernel"}
                  ], "fika/kernel"},
                 {:call, {:/, {1, 0, 22}},
                  [{:integer, {1, 0, 17}, 40}, {:integer, {1, 0, 22}, 50}], "fika/kernel"}
               ],
               "fika/kernel"
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
                      [{:integer, {1, 0, 3}, 10}, {:integer, {1, 0, 8}, 20}], "fika/kernel"},
                     {:call, {:-, {1, 0, 20}},
                      [{:integer, {1, 0, 15}, 30}, {:integer, {1, 0, 20}, 40}], "fika/kernel"}
                   ],
                   "fika/kernel"
                 },
                 {:integer, {1, 0, 26}, 50}
               ],
               "fika/kernel"
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

    test "cannot parse remote function call when module is unknown" do
      str = """
      my_module.my_func(x, 123)
      """

      assert {:error, "Unknown module my_module", _, _, _, _} = TestParser.expression(str)
    end

    test "parses remote function call when module is known" do
      str = """
      use deps/my_module

      my_module.my_func(x, 123)
      """

      args = [
        {:identifier, {3, 20, 39}, :x},
        {:integer, {3, 20, 44}, 123}
      ]

      assert {:ok, [_, function_call], _, context, _, _} =
               TestParser.exp_with_expanded_modules(str)

      assert function_call == {:call, {:my_func, {3, 20, 45}}, args, "deps/my_module"}
      assert context == %{"my_module" => "deps/my_module"}
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
      fn fnfoo do
        123
      end
      """

      assert {:function, [position: {3, 18, 21}],
              {:fnfoo, [], {:type, {1, 0, 8}, :Nothing}, [{:integer, {2, 12, 17}, 123}]}} ==
               TestParser.function_def!(str)
    end

    test "with return type Int" do
      str = """
      fn foo : Int do
        123
      end
      """

      assert {:function, [position: {3, 22, 25}],
              {:foo, [], {:type, {1, 0, 12}, :Int}, [{:integer, {2, 16, 21}, 123}]}} ==
               TestParser.function_def!(str)
    end

    test "with return type :ok" do
      str = """
      fn foo : :ok do
        123
      end
      """

      assert {:function, [position: {3, 22, 25}],
              {:foo, [], {:type, {1, 0, 12}, :ok}, [{:integer, {2, 16, 21}, 123}]}} ==
               TestParser.function_def!(str)
    end

    test "with type params" do
      str = """
      fn foo(a: List(List(List(String)))) : List(Nothing) do
        x
      end
      """

      assert {:function, [position: {3, 59, 62}],
              {:foo,
               [
                 {{:identifier, {1, 0, 8}, :a},
                  {:type, {1, 0, 34}, %T.List{type: %T.List{type: %T.List{type: :String}}}}}
               ], {:type, {1, 0, 51}, %T.List{type: :Nothing}},
               [{:identifier, {2, 55, 58}, :x}]}} ==
               TestParser.function_def!(str)
    end

    test "with args" do
      str = """
      fn foo(x: Int, y: Int) : Int do
        x + y
      end
      """

      assert {:function, [position: {3, 40, 43}],
              {:foo,
               [
                 {{:identifier, {1, 0, 8}, :x}, {:type, {1, 0, 13}, :Int}},
                 {{:identifier, {1, 0, 16}, :y}, {:type, {1, 0, 21}, :Int}}
               ], {:type, {1, 0, 28}, :Int},
               [
                 {:call, {:+, {2, 32, 39}},
                  [{:identifier, {2, 32, 35}, :x}, {:identifier, {2, 32, 39}, :y}], "fika/kernel"}
               ]}} ==
               TestParser.function_def!(str)
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

      arg_union = MapSet.new([:Int, :Float])

      return_union =
        MapSet.new([
          :ok,
          %T.Tuple{elements: [:error, :String]}
        ])

      assert {:function, [position: {7, 120, 123}],
              {:foo,
               [
                 {{:identifier, {1, 0, 8}, :a}, {:type, {1, 0, 21}, %T.Union{types: ^arg_union}}},
                 {{:identifier, {1, 0, 24}, :b}, {:type, {1, 0, 33}, :Nothing}}
               ],
               {:type, {1, 0, 59},
                %T.Union{
                  types: ^return_union
                }},
               [
                 {{:if, {6, 114, 119}}, {:boolean, {2, 63, 72}, true},
                  [{:atom, {3, 76, 83}, :ok}],
                  [
                    {:tuple, {5, 91, 113},
                     [{:atom, {5, 91, 102}, :error}, {:string, {5, 91, 112}, ["not ok"]}]}
                  ]}
               ]}} = TestParser.function_def!(code)
    end

    test "external function" do
      str = """
      ext foo(x: Int, y: Int) : Int = {"Elixir.Test", "foo", [x, y]}
      """

      assert {
               :function,
               [position: {1, 0, 62}],
               {
                 :foo,
                 [
                   {{:identifier, {1, 0, 9}, :x}, {:type, {1, 0, 14}, :Int}},
                   {{:identifier, {1, 0, 17}, :y}, {:type, {1, 0, 22}, :Int}}
                 ],
                 {:type, {1, 0, 29}, :Int},
                 [
                   {:ext_call, {1, 0, 62},
                    {Test, :foo, [{:identifier, {1, 0, 57}, :x}, {:identifier, {1, 0, 60}, :y}],
                     :Int}}
                 ]
               }
             } ==
               TestParser.function_def!(str)
    end

    test "empty body function" do
      str = """
      fn foo do
      end
      """

      assert {:function, [position: {2, 10, 13}], {:foo, [], {:type, {1, 0, 6}, :Nothing}, []}} ==
               TestParser.function_def!(str)
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

  describe "anonymous function" do
    test "with args" do
      str = """
      (x: Int) do x end
      """

      assert {:anonymous_function, {1, 0, 17},
              [{{:identifier, {1, 0, 2}, :x}, {:type, {1, 0, 7}, :Int}}],
              [{:identifier, {1, 0, 13}, :x}]} = TestParser.expression!(str)
    end

    test "without args" do
      str = """
      () do 123 end
      """

      assert {:anonymous_function, {1, 0, 13}, [], [{:integer, {1, 0, 9}, 123}]} =
               TestParser.expression!(str)
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
              ], "fika/kernel"} == TestParser.expression!(str)
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

      assert {:map, {1, 0, 10}, [{{:string, {1, 0, 4}, ["a"]}, {:integer, {1, 0, 9}, 1}}]} ==
               TestParser.expression!(str)
    end

    test "parses map with complex expression" do
      str = """
      {[1+1, 2] => {"1" => {1, 2, 3}}}
      """

      assert {
               :map,
               {1, 0, 32},
               [
                 {
                   {:list, {1, 0, 9},
                    [
                      {:call, {:+, {1, 0, 5}},
                       [{:integer, {1, 0, 3}, 1}, {:integer, {1, 0, 5}, 1}], "fika/kernel"},
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
             } == TestParser.expression!(str)

      str = """
      {true & false => false}
      """

      assert {:map, {1, 0, 23},
              [
                {{:call, {:&, {1, 0, 13}},
                  [{:boolean, {1, 0, 5}, true}, {:boolean, {1, 0, 13}, false}], "fika/kernel"},
                 {:boolean, {1, 0, 22}, false}}
              ]} == TestParser.expression!(str)
    end

    test "parses map with function as key-values" do
      str = """
      {foo(1, 2) => bar(true)}
      """

      assert {:map, {1, 0, 24},
              [
                {{:call, {:foo, {1, 0, 10}}, [{:integer, {1, 0, 6}, 1}, {:integer, {1, 0, 9}, 2}],
                  nil}, {:call, {:bar, {1, 0, 23}}, [{:boolean, {1, 0, 22}, true}], nil}}
              ]} == TestParser.expression!(str)

      str = """
      {&bar => jar(true)}
      """

      assert {
               :map,
               {1, 0, 19},
               [
                 {
                   {:function_ref, {1, 0, 5}, {nil, :bar, []}},
                   {:call, {:jar, {1, 0, 18}}, [{:boolean, {1, 0, 17}, true}], nil}
                 }
               ]
             } == TestParser.expression!(str)
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

      assert {:type, {1, 0, 3}, :Int} == TestParser.type_str!(str)

      str = "Bool"

      assert {:type, {1, 0, 4}, :Bool} == TestParser.type_str!(str)
    end

    test "parses types with an arg" do
      str = "List(Int)"

      assert {:type, {1, 0, 9}, %T.List{type: :Int}} == TestParser.type_str!(str)

      str = "Map(Int, String)"

      assert {:type, {1, 0, 16}, %T.Map{key_type: :Int, value_type: :String}} ==
               TestParser.type_str!(str)
    end

    test "parses types with nested args" do
      str = "List(List(String))"

      assert {:type, {1, 0, 18}, %T.List{type: %T.List{type: :String}}} ==
               TestParser.type_str!(str)

      str = "Map(Int, Map(String, Bool))"

      assert {:type, {1, 0, 27},
              %T.Map{
                key_type: :Int,
                value_type: %T.Map{key_type: :String, value_type: :Bool}
              }} == TestParser.type_str!(str)
    end

    test "parses function type with no args" do
      str = "Fn(-> Int)"

      assert {:type, {1, 0, 10},
              %T.FunctionRef{
                arg_types: [],
                return_type: :Int
              }} == TestParser.type_str!(str)
    end

    test "parses function type with args" do
      str = "Fn(Int, Int -> Int)"

      assert {:type, {1, 0, 19},
              %T.FunctionRef{
                arg_types: [:Int, :Int],
                return_type: :Int
              }} == TestParser.type_str!(str)
    end

    test "record type" do
      str = "{foo: Int, bar: String}"

      assert {:type, {1, 0, 23}, %T.Record{fields: [foo: :Int, bar: :String]}} ==
               TestParser.type_str!(str)
    end

    test "atom type" do
      str = ":foo"

      assert {:type, {1, 0, 4}, :foo} == TestParser.type_str!(str)
    end

    test "list of atom" do
      str = "List(:foo)"

      assert {:type, {1, 0, 10}, %T.List{type: :foo}} == TestParser.type_str!(str)
    end
  end

  describe "function reference" do
    test "parses a function ref with no args" do
      str = """
      &foo
      """

      assert {:function_ref, {1, 0, 4}, {nil, :foo, []}} == TestParser.expression!(str)
    end

    test "cannot parse a remote function ref with unknown module" do
      str = """
      &foo.bar
      """

      assert {:error, _, _, _, _, _} = TestParser.expression(str)
    end

    test "parses a remote function ref with no args when module is known" do
      str = """
      use deps/foo

      &foo.bar
      """

      assert {:ok, [_, function_ref], _, context, _, _} =
               TestParser.exp_with_expanded_modules(str)

      assert function_ref == {:function_ref, {3, 14, 22}, {"deps/foo", :bar, []}}
      assert context == %{"foo" => "deps/foo"}
    end

    test "parses a function ref with arg types" do
      str = """
      &bar(Int, Int)
      """

      assert {:function_ref, {1, 0, 14}, {nil, :bar, [:Int, :Int]}} ==
               TestParser.expression!(str)
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

      assert {:function, [position: {4, 36, 39}],
              {:foo, [], {:type, {2, 20, 26}, :Nothing}, [{:integer, {3, 30, 35}, 123}]}} ==
               TestParser.function_def!(str)
    end

    test "At end of line" do
      str = """
      fn foo do # Comment 1
        123 # Comment 2
      end # Comment 3
      """

      assert {:function, [position: {3, 40, 43}],
              {:foo, [], {:type, {1, 0, 6}, :Nothing}, [{:integer, {2, 22, 27}, 123}]}} ==
               TestParser.function_def!(str)
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

      assert {:function, [position: {3, 22, 25}],
              {:foo, [], {:type, {1, 0, 6}, :Nothing}, [{:string, {2, 10, 21}, ["foo#bar"]}]}} ==
               TestParser.function_def!(str)
    end

    test "Works in between 2 lines" do
      str = """
      x = 1
      # Comment
      y = 2
      """

      assert {:ok,
              [
                {{:=, _}, {:identifier, _, :x}, {:integer, _, 1}},
                {{:=, _}, {:identifier, _, :y}, {:integer, _, 2}}
              ], _, _, _, _} = TestParser.exps(str)
    end

    test "Works in between lines in a function def" do
      str = """
      fn foo do
        x = 1
        # Comment
        y = 2
      end
      """

      assert {
               :function,
               [position: {5, 38, 41}],
               {
                 :foo,
                 '',
                 {:type, {1, 0, 6}, :Nothing},
                 [
                   {{:=, {2, 10, 17}}, {:identifier, {2, 10, 13}, :x},
                    {:integer, {2, 10, 17}, 1}},
                   {{:=, {4, 30, 37}}, {:identifier, {4, 30, 33}, :y}, {:integer, {4, 30, 37}, 2}}
                 ]
               }
             } ==
               TestParser.function_def!(str)
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
          {:call, {:|, _}, [{:boolean, _, true}, {:boolean, _, false}], "fika/kernel"}
        ],
        "fika/kernel"
      } = TestParser.expression!("!(true | false)")
    end

    test "simple usage" do
      str = "false | true"

      assert {:call, {:|, _},
              [
                {:boolean, _, false},
                {:boolean, _, true}
              ], "fika/kernel"} = TestParser.expression!(str)
    end

    test "more complex expressions" do
      str = "true & (false | :true)"

      assert {
               :call,
               {:&, _},
               [
                 {:boolean, _, true},
                 {:call, {:|, _}, [{:boolean, _, false}, {:boolean, _, true}], "fika/kernel"}
               ],
               "fika/kernel"
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

  describe "use module" do
    test "multiple lines" do
      str = """
      use foo/bar/baz
      use foo_1/bar_1
      use foo2
      """

      {:ok, result, _, _, _, _} = TestParser.use_modules(str)

      assert result ==
               [
                 {"foo/bar/baz", {1, 0, 15}},
                 {"foo_1/bar_1", {2, 16, 31}},
                 {"foo2", {3, 32, 40}}
               ]
    end

    test "path with alphanumerics" do
      str = """
      use var/folders/bb/vzln2mls1b53x4bhz4xfdyrm0000gn/T/foo
      """

      {:ok, result, _, _, _, _} = TestParser.use_modules(str)

      assert result ==
               [
                 {"var/folders/bb/vzln2mls1b53x4bhz4xfdyrm0000gn/T/foo", {1, 0, 55}}
               ]
    end
  end

  test "parsing modules" do
    str = """
    use foo/bar

    ext ext1 = {"Test", "foo", []}
    ext ext2(x: Int, y: Int) : Int = {"Elixir.Test", "foo", [x, y]}

    fn foo do
      bar.baz()
    end

    fn foo2 do
      123
    end
    """

    assert Parser.parse_module(str) == {
             :ok,
             [
               use_modules: [{"foo/bar", {1, 0, 11}}],
               function_defs: [
                 {:function, [position: {3, 13, 43}],
                  {:ext1, [], {:type, {3, 13, 21}, :Nothing},
                   [{:ext_call, {3, 13, 43}, {:Test, :foo, [], :Nothing}}]}},
                 {
                   :function,
                   [position: {4, 44, 107}],
                   {
                     :ext2,
                     [
                       {{:identifier, {4, 44, 54}, :x}, {:type, {4, 44, 59}, :Int}},
                       {{:identifier, {4, 44, 62}, :y}, {:type, {4, 44, 67}, :Int}}
                     ],
                     {:type, {4, 44, 74}, :Int},
                     [
                       {:ext_call, {4, 44, 107},
                        {Test, :foo,
                         [{:identifier, {4, 44, 102}, :x}, {:identifier, {4, 44, 105}, :y}],
                         :Int}}
                     ]
                   }
                 },
                 {:function, [position: {8, 131, 134}],
                  {:foo, [], {:type, {6, 109, 115}, :Nothing},
                   [{:call, {:baz, {7, 119, 130}}, [], "foo/bar"}]}},
                 {:function, [position: {12, 153, 156}],
                  {:foo2, [], {:type, {10, 136, 143}, :Nothing},
                   [{:integer, {11, 147, 152}, 123}]}}
               ]
             ]
           }
  end

  describe "identifiers" do
    test "cannot be keywords" do
      keywords = ["fn", "do", "end", "if", "else"]

      for str <- keywords do
        assert {:error, _, _, _, _, _} = TestParser.expression(str)
      end
    end

    test "can start with keywords" do
      str = "fnfoo"

      assert {:identifier, {1, 0, 5}, :fnfoo} == TestParser.expression!(str)
    end
  end
end
