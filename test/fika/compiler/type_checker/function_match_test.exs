defmodule Fika.Compiler.TypeChecker.FunctionMatchTest do
  use ExUnit.Case, async: true

  alias Fika.Compiler.TypeChecker.Types, as: T

  alias Fika.Compiler.{
    FunctionSignature,
    TypeChecker.FunctionMatch
  }

  test "find_by_call" do
    s1 = signature("foo", "bar", [T.Union.new([:a, :b]), :Int])
    s2 = signature("foo", "baz", [T.Union.new([:c, :d])])
    s3 = signature("foo", "baz", ["a", "b"])

    map = %{
      s1 => "value1",
      s2 => "value2",
      s3 => "value3"
    }

    assert FunctionMatch.find_by_call(map, signature("foo", "bar", [:d])) == nil

    assert FunctionMatch.find_by_call(map, signature("foo", "bar", [:a, :Int])) ==
             {s1, "value1", %{}}

    assert FunctionMatch.find_by_call(map, signature("foo", "bar", [:b, :Int])) ==
             {s1, "value1", %{}}

    assert FunctionMatch.find_by_call(map, signature("foo", "baz", [:c])) == {s2, "value2", %{}}
    assert FunctionMatch.find_by_call(map, signature("foo", "baz", [:d])) == {s2, "value2", %{}}

    assert FunctionMatch.find_by_call(map, signature("foo", "baz", [:Int, :String])) ==
             {s3, "value3", %{"a" => :Int, "b" => :String}}
  end

  test "match_signatures" do
    s1 = signature("foo", "bar", [T.Union.new([:a, :b])])
    s2 = signature("foo", "bar", [:a])
    assert FunctionMatch.match_signatures(s1, s2) == %{}

    s1 = signature("foo", "bar", [T.Union.new([:a, :b])])
    s2 = signature("foo", "bar", [:c])
    assert FunctionMatch.match_signatures(s1, s2) == nil

    s1 = signature("foo", "bar", [:a, "a"])
    s2 = signature("foo", "bar", [:a, :Int])
    assert FunctionMatch.match_signatures(s1, s2) == %{"a" => :Int}

    s1 = signature("foo", "bar", ["a", "a"])
    s2 = signature("foo", "bar", [:a, :Int])
    assert FunctionMatch.match_signatures(s1, s2) == nil

    s1 = signature("foo", "bar", ["a", "a"])
    s2 = signature("foo", "bar", [:a, :a])
    assert FunctionMatch.match_signatures(s1, s2) == %{"a" => :a}

    t1 = %T.Tuple{elements: ["a", :Int, :Int]}
    t2 = %T.Tuple{elements: [:a, :Int, :Int]}
    s1 = signature("foo", "bar", [t1])
    s2 = signature("foo", "bar", [t2])
    assert FunctionMatch.match_signatures(s1, s2) == %{"a" => :a}
  end

  # This tests function matching of list.map/2
  test "match_signatures with function refs and type variables - list.map" do
    t1 = [
      %T.List{type: "a"},
      %T.FunctionRef{
        return_type: "b",
        arg_types: ["a"]
      }
    ]

    t2 = [
      %T.List{type: :Int},
      %T.FunctionRef{
        return_type: :String,
        arg_types: [:Int]
      }
    ]

    s1 = signature("foo", "map", t1)
    s2 = signature("foo", "map", t2)
    assert FunctionMatch.match_signatures(s1, s2) == %{"a" => :Int, "b" => :String}
  end

  # This tests function matching of list.reduce/3
  test "match_signatures with function refs and type variables - list.reduce" do
    t1 = [
      %T.List{type: "a"},
      "b",
      %T.FunctionRef{
        return_type: "b",
        arg_types: ["a", "b"]
      }
    ]

    t2 = [
      %T.List{type: :Int},
      :Int,
      %T.FunctionRef{
        return_type: :Int,
        arg_types: [:Int, :Int]
      }
    ]

    s1 = signature("foo", "reduce", t1)
    s2 = signature("foo", "reduce", t2)
    assert FunctionMatch.match_signatures(s1, s2) == %{"a" => :Int, "b" => :Int}
  end

  test "replace_vars" do
    result = {:ok, :Int}
    assert FunctionMatch.replace_vars(result, %{"a" => :String}) == {:ok, :Int}

    result = {:error, "msg"}
    assert FunctionMatch.replace_vars(result, %{"a" => :String}) == {:error, "msg"}

    result = {:ok, "a"}
    assert FunctionMatch.replace_vars(result, %{"a" => :String}) == {:ok, :String}

    result = {:ok, %T.Tuple{elements: [:a, "a"]}}

    assert FunctionMatch.replace_vars(result, %{"a" => :String}) ==
             {:ok, %T.Tuple{elements: [:a, :String]}}

    result = {:ok, T.Union.new([:a, "a"])}

    assert FunctionMatch.replace_vars(result, %{"a" => :String}) ==
             {:ok, T.Union.new([:a, :String])}

    result = {:ok, %T.Map{key_type: :a, value_type: "a"}}

    assert FunctionMatch.replace_vars(result, %{"a" => :String}) ==
             {:ok, %T.Map{key_type: :a, value_type: :String}}

    result = {:ok, %T.List{type: "a"}}

    assert FunctionMatch.replace_vars(result, %{"a" => :String}) ==
             {:ok, %T.List{type: :String}}

    result = {:ok, %T.Effect{type: "a"}}

    assert FunctionMatch.replace_vars(result, %{"a" => :String}) ==
             {:ok, %T.Effect{type: :String}}
  end

  test "replace_vars in a deeply nested type" do
    union = T.Union.new(["a", %T.Map{key_type: "b", value_type: :c}])
    tuple = %T.Tuple{elements: [union, "a", "b"]}
    result = {:ok, tuple}

    assert FunctionMatch.replace_vars(result, %{
             "a" => :String,
             "b" => :b
           }) ==
             {:ok,
              %T.Tuple{
                elements: [
                  T.Union.new([:String, %T.Map{key_type: :b, value_type: :c}]),
                  :String,
                  :b
                ]
              }}
  end

  defp signature(m, f, t) do
    %FunctionSignature{module: m, function: f, types: t}
  end
end
