defmodule Fika.Types.UnionTypeTest do
  use ExUnit.Case, async: true

  alias Fika.Types.Union

  describe "new/1" do
    test "handles a flat list" do
      expected = MapSet.new([:a, :b, :c])
      assert %Union{types: expected} == Union.new([:a, :b, :c])
    end

    test "handles a list which contains nested Unions" do
      expected = MapSet.new([:a, :b, :c, :d])

      assert %Union{types: expected} == Union.new([%Union{types: [:a, :b]}, :c, :d])
      assert %Union{types: expected} == Union.new([:a, %Union{types: [:b, :c]}, :d])
      assert %Union{types: expected} == Union.new([:a, :b, %Union{types: [:c, :d]}])

      assert %Union{types: expected} ==
               Union.new([
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
