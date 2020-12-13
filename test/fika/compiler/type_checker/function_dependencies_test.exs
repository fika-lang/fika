defmodule Fika.Compiler.TypeChecker.FunctionDependenciesTest do
  use ExUnit.Case, async: false

  alias Fika.Compiler.TypeChecker.FunctionDependencies

  setup do
    FunctionDependencies.reset()

    :ok
  end

  describe "set/2" do
    test "should not change state if any of the args is nil" do
      state = Agent.get(FunctionDependencies, & &1)

      FunctionDependencies.set(nil, 1)
      FunctionDependencies.set(1, nil)

      assert state == Agent.get(FunctionDependencies, & &1)
    end

    test "should update the state in an idempotent manner" do
      assert :ok == FunctionDependencies.set("a", "b")
      state = Agent.get(FunctionDependencies, & &1)

      assert :ok == FunctionDependencies.set("a", "b")
      assert state == Agent.get(FunctionDependencies, & &1)

      assert %{"a" => MapSet.new(["b"])} == state
    end

    test "should warn about direct dependency cycles" do
      assert :ok == FunctionDependencies.set("a", "b")

      assert {:error, :cycle_encountered} == FunctionDependencies.set("b", "a")
    end

    test "should warn about indirect dependency cycles" do
      assert :ok == FunctionDependencies.set("a", "b")
      assert :ok == FunctionDependencies.set("b", "c")

      assert {:error, :cycle_encountered} == FunctionDependencies.set("c", "a")
    end
  end
end
