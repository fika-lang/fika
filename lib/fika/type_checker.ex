defmodule Fika.TypeChecker do
  alias Fika.Env
  alias Fika.Types.FunctionRef
  require Logger

  # Given the AST of a module, this function type checks each of the
  # function definitions.
  def check_module({:module, module_name, functions} = ast, env) do
    env = Env.init_module_env(env, module_name, ast)

    Enum.reduce_while(functions, {:ok, env}, fn function, {:ok, env} ->
      {:function, _line, {name, _args, _type, _exprs}} = function
      signature = signature(function, module_name)

      if Env.known_function?(env, signature) do
        Logger.debug("Already checked function: #{signature}. Skipping.")
        {:cont, {:ok, env}}
      else
        case check(function, env) do
          {:ok, type, env} ->
            Logger.debug("Function: #{name} checks type: #{type}")
            {:cont, {:ok, env}}

          error ->
            Logger.debug("Function: #{name} failed type check")
            {:halt, error}
        end
      end
    end)
  end

  # Given the AST of a function definition, this function checks if the return
  # type is indeed the type that's inferred from the body of the function.
  def check({:function, _line, {_, _, return_type, _}} = function, env) do
    {:type, _line, types} = return_type
    expected_types = List.wrap(types)

    # We need to pass inferred_type to the {:check, _, _} tuple so it is accessible in the else clause
    # Enum.any? is used because if any of the accepted types is returned, it should be accepted regardless
    with {:ok, inferred_type, _} = result <- infer(function, env),
         {:check, true, _inferred_type} <-
           {:check, MapSet.new(expected_types) == MapSet.new(List.wrap(inferred_type)),
            List.wrap(inferred_type)} do
      result
    else
      {:check, false, inferred_type} ->
        {:error,
         "Expected type: #{type_to_string(expected_types)}, got: #{type_to_string(inferred_type)}"}

      error ->
        error
    end
  end

  # Given the AST of a function definition, this function infers the
  # return type of the body of the function.
  def infer({:function, _line, {name, args, _type, exprs}}, env) do
    Logger.debug("Inferring type of function: #{name}")

    env = add_args_to_scope(env, args)

    inferred_type =
      env
      |> infer_block(exprs)
      |> add_function_type(name, args)

    inferred_type
  end

  def infer_block(env, []) do
    Logger.debug("Block is empty.")
    {:ok, "Nothing", env}
  end

  def infer_block(env, [exp]) do
    Logger.debug("Block has one exp left")
    infer_exp(env, exp)
  end

  def infer_block(env, [exp | exp_list]) do
    Logger.debug("Block has multiple exps")

    case infer_exp(env, exp) do
      {:ok, _type, env} -> infer_block(env, exp_list)
      error -> error
    end
  end

  # Integer literals
  def infer_exp(env, {:integer, _line, integer}) do
    Logger.debug("Integer #{integer} found. Type: Int")
    {:ok, "Int", env}
  end

  # Booleans
  def infer_exp(env, {:boolean, _line, boolean}) do
    Logger.debug("Boolean #{boolean} found. Type: Bool")
    {:ok, "Bool", env}
  end

  # Variables
  def infer_exp(env, {:identifier, _line, name}) do
    type = Env.scope_get(env, name)

    if type do
      Logger.debug("Variable type found from scope: #{name}:#{type}")
      {:ok, type, env}
    else
      Logger.debug("Variable type not found in scope: #{name}")
      {:error, "Unknown variable: #{name}"}
    end
  end

  # Function calls
  def infer_exp(env, {:call, {name, _line}, args, module}) do
    exp = %{args: args, name: name}
    module_name = module || Env.current_module(env)
    Logger.debug("Inferring type of function: #{name}")
    infer_args(env, exp, module_name)
  end

  # Function calls using reference
  # exp has to be a function ref type
  def infer_exp(env, {:call, {exp, _line}, args}) do
    case infer_exp(env, exp) do
      {:ok, %FunctionRef{arg_types: arg_types, return_type: type}, env} ->
        with {:ok, inferred_arg_types, env} <- do_infer_args_without_name(env, args),
             {:ok, _inferred_arg_types} <- validate_types(arg_types, inferred_arg_types) do
          {:ok, type, env}
        else
          {_, inferred_arg_types} ->
            error =
              "Expected function reference to be called with" <>
                " arguments (#{format_arg_types(arg_types)}), but it was called " <>
                "with arguments (#{format_arg_types(inferred_arg_types)})"

            {:error, error}
        end

      {:ok, type, _} ->
        {:error, "Expected a function reference, but got type: #{format_arg_types(type)}"}

      error ->
        error
    end
  end

  # =
  def infer_exp(env, {{:=, _}, {:identifier, _line, left}, right}) do
    case infer_exp(env, right) do
      {:ok, type, env} ->
        Logger.debug("Adding variable to scope: #{left}:#{type}")
        env = Env.scope_add(env, left, type)
        {:ok, List.wrap(type), env}

      error ->
        error
    end
  end

  # String
  def infer_exp(env, {:string, _line, string}) do
    Logger.debug("String #{string} found. Type: String")
    {:ok, "String", env}
  end

  # List
  def infer_exp(env, {:list, _, exps}) do
    infer_list_exps(env, exps)
  end

  # Tuple
  def infer_exp(env, {:tuple, _, exps}) do
    case do_infer_tuple_exps(exps, env) do
      {:ok, exp_types, env} ->
        exp_types =
          exp_types
          |> Enum.reverse()
          |> Enum.join(",")

        {:ok, "{#{exp_types}}", env}

      error ->
        error
    end
  end

  # Record
  def infer_exp(env, {:record, _, name, key_values}) do
    if name do
      # Lookup type of name, ensure it matches.
      Logger.error("Not implemented")
    else
      case do_infer_key_values(key_values, env) do
        {:ok, k_v_types, env} ->
          k_v_types =
            k_v_types
            |> Enum.reverse()
            |> Enum.join(",")

          {:ok, "{#{k_v_types}}", env}

        error ->
          error
      end
    end
  end

  # Function ref
  def infer_exp(env, {:function_ref, _, {module, function_name, arg_types}}) do
    Logger.debug("Inferring type of function: #{function_name}")

    module_name = module || Env.current_module(env)
    signature = get_signature(module_name, function_name, arg_types)

    result =
      if module_name == Env.current_module(env) && !Env.known_function?(env, signature) do
        Logger.debug("Checking unknown function #{signature} in module: #{module_name}")

        case check_by_signature(env, signature) do
          {:ok, _, _} = result -> result
          error -> error
        end
      else
        get_type_by_signature(env, signature)
      end

    case result do
      {:ok, type, env} ->
        type = %FunctionRef{arg_types: arg_types, return_type: type}
        {:ok, type, env}

      error ->
        error
    end
  end

  # Atom value
  def infer_exp(env, {:atom, _line, atom}) do
    Logger.debug("Atom value found. Type: #{atom}")
    {:ok, atom, env}
  end

  # if-else expression
  def infer_exp(env, {{:if, _line}, condition, if_block, else_block}) do
    Logger.debug("Inferring an if-else expression")

    case infer_if_else_condition(env, condition) do
      {:ok, "Bool", env} -> infer_if_else_blocks(env, if_block, else_block)
      error -> error
    end
  end

  defp validate_types(arg_types, inferred_arg_types)
       when not is_list(arg_types) or not is_list(inferred_arg_types) or
              length(arg_types) != length(inferred_arg_types),
       do: {:error, inferred_arg_types}

  defp validate_types(arg_types, inferred_arg_types) do
    arg_types
    |> Enum.zip(inferred_arg_types)
    |> Enum.all?(fn {arg, inferred} ->
      inferred in List.wrap(arg)
    end)
    |> if do
      {:ok, inferred_arg_types}
    else
      {:error, inferred_arg_types}
    end
  end

  defp infer_if_else_condition(env, condition) do
    case infer_exp(env, condition) do
      {:ok, "Bool", _} = type ->
        Logger.debug("if-else condition has return type: Bool")
        type

      {_, inferred_type, _env} ->
        Logger.debug("if-else condition has wrong return type: #{inferred_type}")
        {:error, "Wrong type for if condition. Expected: Bool, Got: #{inferred_type}"}
    end
  end

  defp infer_if_else_blocks(env, if_block, else_block) do
    if_inferred = infer_block(env, if_block)
    else_inferred = infer_block(env, else_block)

    with {:ok, if_type, env} <- if_inferred,
         {:ok, else_type, ^env} <- else_inferred do
      if_else_type =
        if if_type == else_type do
          if_type
        else
          [List.wrap(if_type) | List.wrap(else_type)]
          |> List.flatten()
          |> MapSet.new()
          |> Enum.to_list()
        end

      {:ok, if_else_type, env}
    end
  end

  defp do_infer_key_values(key_values, env) do
    Enum.reduce_while(key_values, {:ok, [], env}, fn {k, v}, {:ok, acc, env} ->
      case infer_exp(env, v) do
        {:ok, type, env} ->
          {:identifier, _, key} = k
          {:cont, {:ok, ["#{key}:#{type}" | acc], env}}

        error ->
          {:halt, error}
      end
    end)
  end

  defp do_infer_tuple_exps(exps, env) do
    Enum.reduce_while(exps, {:ok, [], env}, fn exp, {:ok, acc, env} ->
      case infer_exp(env, exp) do
        {:ok, exp_type, env} ->
          {:cont, {:ok, [exp_type | acc], env}}

        error ->
          {:halt, error}
      end
    end)
  end

  def infer_args(env, exp, module) do
    case do_infer_args(env, exp) do
      {:ok, type_acc, env} ->
        signature = get_signature(module, exp.name, type_acc)

        if module == Env.current_module(env) && !Env.known_function?(env, signature) do
          Logger.debug("Checking unknown function #{signature} in module: #{module}")

          case check_by_signature(env, signature) do
            {:ok, _, _} = result -> result
            error -> error
          end
        else
          get_type_by_signature(env, signature)
        end

      error ->
        error
    end
  end

  defp infer_list_exps(env, []) do
    {:ok, "List(Nothing)", env}
  end

  defp infer_list_exps(env, [exp]) do
    case infer_exp(env, exp) do
      {:ok, type, env} -> {:ok, wrap_list(type), env}
      error -> error
    end
  end

  defp infer_list_exps(env, [exp | rest]) do
    {:ok, type, env} = infer_exp(env, exp)

    Enum.reduce_while(rest, {:ok, wrap_list(type), env}, fn exp, {:ok, acc_type, acc_env} ->
      case infer_exp(acc_env, exp) do
        {:ok, ^type, env} ->
          acc = {:ok, acc_type, env}
          {:cont, acc}

        {:ok, diff_type, _} ->
          error =
            {:error,
             "Elements of list have different types. Expected: #{type}, got: #{diff_type}"}

          {:halt, error}

        error ->
          {:halt, error}
      end
    end)
  end

  defp wrap_list(type) when is_atom(type), do: "List(:#{type})"
  defp wrap_list(type), do: "List(#{type})"

  defp do_infer_args(env, exp) do
    exp.args
    |> Enum.reduce_while({:ok, [], env}, fn arg, {:ok, type_acc, env} ->
      case infer_exp(env, arg) do
        {:ok, type, env} ->
          Logger.debug("Argument of #{exp.name} is type: #{type}")
          {:cont, {:ok, [type | type_acc], env}}

        error ->
          Logger.debug("Argument of #{exp.name} cannot be inferred")
          {:halt, error}
      end
    end)
    |> case do
      {:ok, types, env} ->
        corrected_types = types |> List.flatten() |> Enum.reverse()
        {:ok, corrected_types, env}

      error ->
        error
    end
  end

  defp do_infer_args_without_name(env, args) do
    args
    |> Enum.reduce_while({:ok, [], env}, fn arg, {:ok, type_acc, env} ->
      case infer_exp(env, arg) do
        {:ok, type, env} ->
          Logger.debug("Argument is type: #{type}")
          {:cont, {:ok, [type | type_acc], env}}

        error ->
          Logger.debug("Argument cannot be inferred")
          {:halt, error}
      end
    end)
    |> case do
      {:ok, acc_types, env} ->
        corrected_types = acc_types |> List.flatten() |> Enum.reverse()
        {:ok, corrected_types, env}

      error ->
        error
    end
  end

  defp get_type_by_signature(env, signature) do
    type = Env.get_function_type(env, signature)

    if type do
      Logger.debug("Type of function signature: #{signature} is: #{type}")
      {:ok, type, env}
    else
      Logger.debug("Type of function signature: #{signature} not found")
      {:error, "Unknown function: #{signature}"}
    end
  end

  defp add_args_to_scope(env, args) do
    Enum.reduce(args, env, fn {{:identifier, _, name}, {:type, _, type}}, env ->
      Logger.debug("Adding arg type to scope: #{name}:#{type}")
      Env.scope_add(env, name, type)
    end)
  end

  defp add_function_type({:ok, type, env}, name, args) do
    types =
      Enum.map(args, fn {_, {_, _, type}} ->
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
    "#{module}.#{name}(#{format_arg_types(arg_types)})"
  end

  defp format_arg_types(types) do
    types
    |> List.wrap()
    |> Enum.map(fn union ->
      type_to_string(union)
    end)
    |> Enum.join(",")
  end

  defp type_to_string(type) do
    type
    |> List.wrap()
    |> List.flatten()
    |> Enum.map(fn
      x when is_atom(x) -> ":#{x}"
      x -> x
    end)
    |> Enum.join(" | ")
  end

  defp check_by_signature(env, signature) do
    functions = Env.ast_functions(env)
    module = Env.current_module(env)

    function =
      Enum.find(functions, fn function ->
        signature(function, module) == signature
      end)

    if function do
      check(function, env)
    else
      {:error, "Undefined function: #{signature} in module #{module}"}
    end
  end
end
