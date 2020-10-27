defmodule Fika.Env do
  @moduledoc """
  Env is the state that gets updated as the typechecker walks through
  the AST. Right now it's just a fairly stupid map, but as the typechecker
  grows, we'll make this more organized.
  """

  def init do
    %{
      # This is a map of known function signatures and their return types.
      # As a hack for now, we store kernel function signatures right here.
      function_types: %{
        "kernel.+(Int,Int)" => :Int,
        "kernel.+(Int,Float)" => :Float,
        "kernel.+(Float,Int)" => :Float,
        "kernel.+(Float,Float)" => :Float,
        "kernel.-(Int,Int)" => :Int,
        "kernel.-(Int,Float)" => :Float,
        "kernel.-(Float,Int)" => :Float,
        "kernel.-(Float,Float)" => :Float,
        "kernel.*(Int,Int)" => :Int,
        "kernel.*(Int,Float)" => :Float,
        "kernel.*(Float,Int)" => :Float,
        "kernel.*(Float,Float)" => :Float,
        "kernel./(Int,Int)" => :Float,
        "kernel./(Int,Float)" => :Float,
        "kernel./(Float,Int)" => :Float,
        "kernel./(Float,Float)" => :Float,
        "kernel.|(Bool,Bool)" => :Bool,
        "kernel.&(Bool,Bool)" => :Bool,
        "kernel.!(Bool)" => :Bool,
        "kernel.-(Int)" => :Int
      }
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

  def get_function_type(env, signature) do
    get_in(env, [:function_types, signature])
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
    update_in(env, [:module_env, :known_functions], &[signature | &1])
  end

  def ast_functions(env) do
    {:module, _module_name, functions} = get_in(env, [:module_env, :ast])
    functions
  end
end
