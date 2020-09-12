defmodule Fika.TypeChecker do
  alias Fika.Env
  require Logger

  # Given the AST of a module, this function type checks each of the
  # function definitions.
  def check_module({:module, module_name, functions} = ast, env) do
    env = Env.init_module_env(env, module_name, ast)
    Enum.reduce_while(functions, {:ok, env}, fn function, {:ok, env} ->
      {:function, _line, {name, _args, _type, _exprs}} = function
      signature = signature(function, module_name)

      if Env.known_function?(env, signature) do
        Logger.debug "Already checked function: #{signature}. Skipping."
        {:cont, {:ok, env}}
      else
        case check(function, env) do
          {:ok, type, env} ->
            Logger.debug "Function: #{name} checks type: #{type}"
            {:cont, {:ok, env}}
          error ->
            Logger.debug "Function: #{name} failed type check"
            {:halt, error}
        end
      end
    end)
  end

  # Given the AST of a function definition, this function checks if the return
  # type is indeed the type that's inferred from the body of the function.
  def check({:function, _line, {_, _, return_type, _}} = function, env) do
    {:type, _line, type} = return_type
    expected_type = type

    case infer(function, env) do
      {:ok, ^expected_type, _env} = result ->
        result
      {:ok, other_type, _} ->
        {:error, "Expected type: #{expected_type}, got: #{other_type}"}
      error ->
        error
    end
  end

  # Given the AST of a function definition, this function infers the
  # return type of the body of the function.
  def infer({:function, _line, {name, args, _type, exprs}}, env) do
    Logger.debug("Inferring type of function: #{name}")

    env = add_args_to_scope(env, args)

    env
    |> infer_block(exprs)
    |> add_function_type(name, args)
  end

  def infer_block(env, []) do
    Logger.debug "Block is empty."
    {:ok, :Nothing, env}
  end
  def infer_block(env, [exp]) do
    Logger.debug "Block has one exp left"
    infer_exp(env, exp)
  end
  def infer_block(env, [exp | exp_list]) do
    Logger.debug "Block has multiple exps"
    case infer_exp(env, exp) do
      {:ok, _type, env} -> infer_block(env, exp_list)
      error -> error
    end
  end

  # Integer literals
  def infer_exp(env, {:integer, _line, integer}) do
    Logger.debug "Integer #{integer} found. Type: #{:Int}"
    {:ok, :Int, env}
  end
  # Variables
  def infer_exp(env, {:identifier, _line, name}) do
    type = Env.scope_get(env, name)
    if type do
      Logger.debug "Variable type found from scope: #{name}:#{type}"
      {:ok, type, env}
    else
      Logger.debug "Variable type not found in scope: #{name}"
      {:error, "Unknown variable: #{name}"}
    end
  end

  defp add_args_to_scope(env, args) do
    Enum.reduce(args, env, fn {{:identifier, _, name}, {:type, _, type}}, env ->
      Logger.debug("Adding arg type to scope: #{name}:#{type}")
      Env.scope_add(env, name, type)
    end)
  end

  defp add_function_type({:ok, type, env}, name, args) do
    types = Enum.map(args, fn {_, {_, _, type}} ->
      type
    end)
    module = Env.current_module(env)
    signature = get_signature(module, name, types)

    env = Env.add_function_type(env, signature, type)

    {:ok, type, env}
  end
  defp add_function_type(error, _, _) do
    error
  end

  defp signature({:function, _line, {name, args, _type, _exprs}}, module) do
    arg_types = Enum.map(args, fn {_, {:type, _, type}} -> type end)
    get_signature(module, name, arg_types)
  end

  defp get_signature(module, name, arg_types) do
    "#{module}.#{name}(#{Enum.join(arg_types, ",")})"
  end
end
