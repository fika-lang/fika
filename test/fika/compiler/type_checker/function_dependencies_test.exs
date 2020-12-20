defmodule Fika.Compiler.TypeChecker.FunctionDependenciesTest do
  use ExUnit.Case, async: false

  alias Fika.Compiler.TypeChecker.FunctionDependencies

  setup do
    FunctionDependencies.reset()

    :ok
  end

  describe "set/2" do
    test "should not change state if any of the args is nil" do
      state = FunctionDependencies.get_dependency_graph()

      FunctionDependencies.set(nil, 1)
      FunctionDependencies.set(1, nil)

      assert state == FunctionDependencies.get_dependency_graph()
    end

    test "should update the state in an idempotent manner" do
      assert :ok == FunctionDependencies.set("a", "b")
      graph = FunctionDependencies.get_dependency_graph()

      assert :ok == FunctionDependencies.set("a", "b")
      assert graph == FunctionDependencies.get_dependency_graph()

      assert %{edges: [{"a", "b"}], vertices: ["a", "b"]} == graph
    end

    @tag :focus
    test "should warn about direct dependency cycles" do
      assert :ok == FunctionDependencies.set("a", "b")

      assert {:error, :cycle_encountered} == FunctionDependencies.set("b", "a")
    end

    test "should warn about indirect dependency cycles" do
      assert :ok == FunctionDependencies.set("a", "b")
      assert :ok == FunctionDependencies.set("b", "c")
      assert {:error, :cycle_encountered} == FunctionDependencies.set("c", "a")

      nodes = ["a", "b", "c"]

      for x <- nodes, y <- nodes do
        assert {:error, :cycle_encountered} == FunctionDependencies.set(x, y)
      end
    end

    test "should correctly handle acyclic graphs" do
      assert :ok == FunctionDependencies.set("a", "x")
      assert :ok == FunctionDependencies.set("b", "c")
      assert :ok == FunctionDependencies.set("c", "a")
    end
  end
end
