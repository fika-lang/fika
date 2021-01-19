defmodule Fika.Compiler.TypeChecker.MatchTest do
  use ExUnit.Case, async: true

  alias Fika.Compiler.TypeChecker.Types, as: T

  alias Fika.Compiler.TypeChecker.{
    Match
  }

  test "match atoms" do
    rhs = T.Union.new([:a, :b, :c])
    str = ":a"
    lhs = TestParser.expression!(str)
    env = %{}

    assert Match.match(env, lhs, rhs) == :error

    rhs = :a
    assert {:ok, env} = Match.match(env, lhs, rhs)
  end

  test "match integers" do
    rhs = :Int
    str = "x"
    lhs = TestParser.expression!(str)
    env = %{scope: %{}}

    assert {:ok, env} = Match.match(env, lhs, rhs)
    assert env.scope[:x] == :Int

    rhs = :Int
    str = "1"
    lhs = TestParser.expression!(str)
    env = %{}
    assert Match.match(env, lhs, rhs) == :error
  end

  test "match tuples" do
    rhs = %T.Tuple{elements: [:Int, %T.Tuple{elements: [:a, :b]}, :String]}
    str = "{x, y, z}"
    lhs = TestParser.expression!(str)
    env = %{scope: %{}}

    assert {:ok, env} = Match.match(env, lhs, rhs)
    assert env.scope[:x] == :Int
    assert env.scope[:y] == %T.Tuple{elements: [:a, :b]}
    assert env.scope[:z] == :String

    str = "{x, {foo, bar}, z}"
    lhs = TestParser.expression!(str)
    env = %{scope: %{}}

    assert {:ok, env} = Match.match(env, lhs, rhs)
    assert env.scope[:foo] == :a
    assert env.scope[:bar] == :b
  end

  test "match records" do
    rhs = %T.Record{fields: [{:name, :String}, {:id, :Int}]}
    str = "{name: name, id: x}"
    lhs = TestParser.expression!(str)
    env = %{scope: %{}}

    assert {:ok, env} = Match.match(env, lhs, rhs)
    assert env.scope[:name] == :String
    assert env.scope[:x] == :Int
  end

  test "match strings" do
    rhs = :String
    str = "x"
    lhs = TestParser.expression!(str)
    env = %{scope: %{}}

    assert {:ok, env} = Match.match(env, lhs, rhs)
    assert env.scope[:x] == :String
  end

  test "match_case when lhs does not match any in a union" do
    rhs = T.Union.new([:a, :b, :c])
    pattern = TestParser.expression!(":d")
    env = %{scope: %{}}

    assert Match.match_case(env, pattern, rhs) == :error
  end

  test "match_case for strings" do
    rhs = :String
    pattern = TestParser.expression!("\"foo\"")
    assert {:ok, _, [:String]} = Match.match_case(%{}, pattern, rhs)
  end

  test "match_case when lhs matches one of many in a union" do
    rhs = T.Union.new([:a, :b, :c])
    pattern = TestParser.expression!(":a")
    env = %{scope: %{}}

    assert {:ok, _, unmatched} = Match.match_case(env, pattern, rhs)
    assert unmatched == [:b, :c]
  end

  test "match_case when lhs matches all of the union" do
    rhs = T.Union.new([:a, :b, :c])
    pattern = TestParser.expression!("x")
    env = %{scope: %{}}

    assert {:ok, env, []} = Match.match_case(env, pattern, rhs)
    assert env.scope[:x] == T.Union.new([:a, :b, :c])
  end

  test "match_case when rhs is a union of tuples" do
    ok_int = %T.Tuple{elements: [:ok, :Int]}
    error_str = %T.Tuple{elements: [:error, :String]}
    rhs = T.Union.new([ok_int, error_str])
    pattern = TestParser.expression!("{:ok, x}")
    env = %{scope: %{}}

    assert {:ok, env, unmatched} = Match.match_case(env, pattern, rhs)
    assert env.scope[:x] == :Int
    assert unmatched == [error_str]

    pattern = TestParser.expression!("{:ok, 1}")
    assert {:ok, env, unmatched} = Match.match_case(env, pattern, rhs)
    assert unmatched == [error_str, ok_int]
  end

  test "match_case when rhs is a union of tuples - part 2" do
    rhs = %T.Tuple{elements: [T.Union.new([:a, :b]), :Int]}
    pattern = TestParser.expression!("{:a, 2}")
    env = %{scope: %{}}

    assert {:ok, env, unmatched} = Match.match_case(env, pattern, rhs)
    assert unmatched == [%T.Tuple{elements: [:a, :Int]}, %T.Tuple{elements: [:b, :Int]}]
  end

  test "match_case with a union with other unions nested within" do
    inner_union_1 = T.Union.new([:a, :b])
    inner_union_2 = T.Union.new([:c, :d])
    ok = %T.Tuple{elements: [:ok, inner_union_1]}
    error = %T.Tuple{elements: [:error, inner_union_2]}
    rhs = T.Union.new([ok, error])
    env = %{scope: %{}}

    pattern = TestParser.expression!("{:ok, x}")
    assert {:ok, env, unmatched} = Match.match_case(env, pattern, rhs)
    assert env.scope[:x] == inner_union_1
    assert unmatched == Match.expand_unions(error)

    pattern = TestParser.expression!("{:ok, :a}")
    assert {:ok, env, unmatched} = Match.match_case(%{}, pattern, rhs)

    assert unmatched == [
             %T.Tuple{elements: [:error, :c]},
             %T.Tuple{elements: [:error, :d]},
             %T.Tuple{elements: [:ok, :b]}
           ]

    pattern = TestParser.expression!("{:error, :c}")
    assert {:ok, env, unmatched} = Match.match_case(%{}, pattern, rhs)

    assert unmatched == [
             %T.Tuple{elements: [:error, :d]},
             %T.Tuple{elements: [:ok, :a]},
             %T.Tuple{elements: [:ok, :b]}
           ]

    env = %{scope: %{}}
    pattern = TestParser.expression!("x")
    assert {:ok, env, unmatched} = Match.match_case(env, pattern, rhs)
    assert unmatched == []

    assert env.scope[:x] ==
             T.Union.new([
               %T.Tuple{elements: [:error, :c]},
               %T.Tuple{elements: [:error, :d]},
               %T.Tuple{elements: [:ok, :a]},
               %T.Tuple{elements: [:ok, :b]}
             ])
  end

  test "match_case for records" do
    rhs = %T.Record{fields: [name: :String, id: :Int]}
    env = %{scope: %{}}
    pattern = TestParser.expression!("{name: x}")
    assert {:ok, env, unmatched} = Match.match_case(env, pattern, rhs)
    assert unmatched == []
    assert env.scope[:x] == :String

    pattern = TestParser.expression!("{id: 1}")
    assert {:ok, env, unmatched} = Match.match_case(%{}, pattern, rhs)
    assert unmatched == [rhs]
  end

  test "match_case for record with a union inside" do
    str = "{name: String, id: Int, x: :a | :b | :c}"
    {:type, _, rhs} = TestParser.type_str!(str)

    pattern = TestParser.expression!("{x: :a}")
    assert {:ok, env, unmatched} = Match.match_case(%{}, pattern, rhs)

    assert unmatched == [
             %T.Record{fields: [id: :Int, name: :String, x: :b]},
             %T.Record{fields: [id: :Int, name: :String, x: :c]}
           ]
  end

  test "expand_unions" do
    type = %T.Tuple{elements: [T.Union.new([:a, :b]), :Int, T.Union.new([:c, :d])]}

    assert Match.expand_unions(type) == [
             %T.Tuple{elements: [:a, :Int, :c]},
             %T.Tuple{elements: [:a, :Int, :d]},
             %T.Tuple{elements: [:b, :Int, :c]},
             %T.Tuple{elements: [:b, :Int, :d]}
           ]

    type = %T.Tuple{elements: [T.Union.new([:a, :b]), :Int, type]}

    assert Match.expand_unions(type) == [
             %T.Tuple{elements: [:a, :Int, %T.Tuple{elements: [:a, :Int, :c]}]},
             %T.Tuple{elements: [:a, :Int, %T.Tuple{elements: [:a, :Int, :d]}]},
             %T.Tuple{elements: [:a, :Int, %T.Tuple{elements: [:b, :Int, :c]}]},
             %T.Tuple{elements: [:a, :Int, %T.Tuple{elements: [:b, :Int, :d]}]},
             %T.Tuple{elements: [:b, :Int, %T.Tuple{elements: [:a, :Int, :c]}]},
             %T.Tuple{elements: [:b, :Int, %T.Tuple{elements: [:a, :Int, :d]}]},
             %T.Tuple{elements: [:b, :Int, %T.Tuple{elements: [:b, :Int, :c]}]},
             %T.Tuple{elements: [:b, :Int, %T.Tuple{elements: [:b, :Int, :d]}]}
           ]

    type = T.Union.new([:a, :b])
    assert Match.expand_unions(type) == [:a, :b]

    type = :Int
    assert Match.expand_unions(type) == [:Int]

    str = "{name: String, id: Int, x: :a | :b}"
    {:type, _, type} = TestParser.type_str!(str)

    assert Match.expand_unions(type) == [
             %T.Record{fields: [id: :Int, name: :String, x: :a]},
             %T.Record{fields: [id: :Int, name: :String, x: :b]}
           ]
  end

  test "do_expand_all" do
    assert Match.do_expand_all([:a]) == [[:a]]

    assert Match.do_expand_all([:a, :b]) == [[:a, :b]]

    u1 = T.Union.new([:a, :b])
    assert Match.do_expand_all([u1, :c]) == [[:a, :c], [:b, :c]]

    u1 = T.Union.new([:a, :b])
    u2 = T.Union.new([:c, :d])
    assert Match.do_expand_all([u1, u2]) == [[:a, :c], [:a, :d], [:b, :c], [:b, :d]]

    assert Match.do_expand_all([u1, :x, u2]) == [
             [:a, :x, :c],
             [:a, :x, :d],
             [:b, :x, :c],
             [:b, :x, :d]
           ]
  end
end
