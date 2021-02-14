defmodule Fika.OperatorsTest do
  use ExUnit.Case, async: true
  alias TestEvaluator, as: TE
  alias TestParser, as: TP

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
                 {:call, {:!, {1, 0, 14}}, [{:identifier, {1, 0, 14}, :something}], "fika/kernel"}
               ],
               "fika/kernel"
             } == TestParser.expression!("1 * !something")

      assert {
               :call,
               {:/, {1, 0, 14}},
               [
                 {:call, {:!, {1, 0, 10}}, [{:identifier, {1, 0, 10}, :something}],
                  "fika/kernel"},
                 {:integer, {1, 0, 14}, 2}
               ],
               "fika/kernel"
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
                  "fika/kernel"},
                 {:call, {:>, {1, 0, 14}}, [{:integer, {1, 0, 10}, 2}, {:integer, {1, 0, 14}, 2}],
                  "fika/kernel"}
               ],
               "fika/kernel"
             } == TestParser.expression!("1 < 1 == 2 > 2")

      assert {
               :call,
               {:!=, {1, 0, 16}},
               [
                 {:call, {:<=, {1, 0, 6}}, [{:integer, {1, 0, 1}, 1}, {:integer, {1, 0, 6}, 1}],
                  "fika/kernel"},
                 {:call, {:>=, {1, 0, 16}},
                  [{:integer, {1, 0, 11}, 2}, {:integer, {1, 0, 16}, 3}], "fika/kernel"}
               ],
               "fika/kernel"
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
               {:foo, [], {:type, {1, 0, 6}, nil},
                [
                  {:identifier, {2, 10, 13}, :x},
                  {:call, {:-, {3, 14, 19}}, [{:identifier, {3, 14, 19}, :y}], "fika/kernel"}
                ]}
             } == TestParser.function_def!(str)
    end
  end
end
