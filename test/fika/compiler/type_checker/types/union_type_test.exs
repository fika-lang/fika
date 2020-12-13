defmodule Fika.Compiler.TypeChecker.Types.UnionTypeTest do
  use ExUnit.Case, async: true

  alias Fika.Compiler.TypeChecker.Types.{Loop, Union}

  describe "new/1" do
    test "handles a flat list" do
      expected = MapSet.new([:a, :b, :c])
      assert %Union{types: expected} == Union.new([:a, :b, :c])
    end
  end

  describe "flatten_types/1" do
    test "handles a list which contains nested Unions" do
      expected = MapSet.new([:a, :b, :c, :d])

      assert expected == Union.flatten_types([%Union{types: [:a, :b]}, :c, :d])
      assert expected == Union.flatten_types([:a, %Union{types: [:b, :c]}, :d])
      assert expected == Union.flatten_types([:a, :b, %Union{types: [:c, :d]}])

      assert expected ==
               Union.flatten_types([
                 %Union{
                   types: [
                     %Union{types: [:a, :b]},
                     %Union{types: [:c, :d]}
                   ]
                 }
               ])
    end
  end

  describe "find_and_expand_loops/1" do
    test "works when received types do not include loops" do
      types = [:a, :b, %Union{types: [:c, :d]}]
      assert {false, MapSet.new(types)} == Union.find_and_expand_loops(types)
    end

    test "works when received types include empty loops" do
      types = [:a, :b]

      assert {true, MapSet.new(types)} ==
               Union.find_and_expand_loops([%Loop{} | types])
    end

    test "works when received types include non-empty loops" do
      types = [:a, :b]

      assert {true, MapSet.new([:c | types])} ==
               Union.find_and_expand_loops([%Loop{type: :c} | types])
    end
  end
end
