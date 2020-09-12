defmodule Fika.Env do
  @moduledoc """
  Env is the state that gets updated as the typechecker walks through
  the AST. Right now it's just a fairly stupid map, but as the typechecker
  grows, we'll make this more organized.
  """

  def init do
    %{
      # This is a map of known function signatures and their return types.
      function_types: %{}
    }
  end

  def init_module_env(env, module_name, ast) do
    put_in(env, [:module_env], %{
      module_name: module_name,
      known_functions: [],
      scope: %{},
      ast: ast
    })
  end

  def add_function_type(env, signature, type) do
    env
    |> put_in([:function_types, signature], type)
    |> add_known_function(signature)
  end

  def current_module(env) do
    get_in(env, [:module_env, :module_name])
  end

  def known_function?(env, signature) do
    known_functions = get_in(env, [:module_env, :known_functions])
    signature in known_functions
  end

  def scope_add(env, name, type) do
    put_in(env, [:module_env, :scope, name], type)
  end

  def scope_get(env, name) do
    get_in(env, [:module_env, :scope, name])
  end

  defp add_known_function(env, signature) do
    update_in(env, [:module_env, :known_functions], & [signature | &1])
  end
end
