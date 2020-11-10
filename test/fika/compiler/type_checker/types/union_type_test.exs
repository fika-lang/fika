defmodule Fika.Compiler.TypeChecker.Types.UnionTypeTest do
  use ExUnit.Case, async: true

  alias Fika.Compiler.TypeChecker.Types.Union

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
end
