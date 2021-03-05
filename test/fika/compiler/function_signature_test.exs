defmodule Fika.Compiler.FunctionSignatureTest do
  use ExUnit.Case, async: true

  alias Fika.Compiler.FunctionSignature

  test "to_string" do
    struct = %FunctionSignature{module: "foo", function: "bar", types: [:Int, :Float]}
    assert to_string(struct) == "foo.bar(Int, Float)"

    struct = %FunctionSignature{module: "foo", function: "bar"}
    assert to_string(struct) == "foo.bar()"
  end
end
