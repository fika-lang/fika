defmodule Fika.Compiler.TypeChecker do
  alias Fika.Compiler.TypeChecker.Types, as: T

  alias Fika.Compiler.{
    CodeServer,
    FunctionSignature
  }

  alias Fika.Compiler.TypeChecker.{
    ParallelTypeChecker,
    SequentialTypeChecker,
    Match
  }

  require Logger

  defmodule Env do
    defstruct [
      :ast,
      :latest_called_function,
      :type_checker_pid,
      :module,
      :module_name,
      :file,
      :current_signature,
      has_effect: false,
      scope: %{}
    ]

    def add_variable_to_scope(env, variable, type) do
      %{env | scope: put_in(env.scope, [variable], type)}
    end

    def update_scope(env, variable, update_fn) do
      %{env | scope: update_in(env.scope, [variable], update_fn)}
    end
  end

  # Given the AST of a function definition, this function checks if the return
  # type is indeed the type that's inferred from the body of the function.
  def check({:function, _line, {_, _, return_type, _}} = function, %Env{} = env) do
    {:type, _line, expected_type} = return_type

    case infer(function, env) do
      {:ok, ^expected_type} = result ->
        result

      {:ok, inferred_type} ->
        {:error, "Expected type: #{expected_type}, got: #{inferred_type}"}

      error ->
        error
    end
  end

  defp unwrap_loop(env, t, %T.Loop{type: t} = loop_type) do
    # The function can be a top-level function which depends on a loop
    # In this case, we can unwrap the loop

    case CodeServer.check_cycle(env.current_signature) do
      :ok ->
        {:ok, t}

      _ ->
        {:error, "Expected type: #{t}, got: #{loop_type}"}
    end
  end

  defp unwrap_loop(_env, t, t), do: {:ok, t}

  defp unwrap_loop(_env, expected_type, inferred_type),
    do: {:error, "Expected type: #{expected_type}, got: #{inferred_type}"}

  # Given the AST of a function definition, this function infers the
  # return type of the body of the function.
  def infer({:function, _line, {name, args, _type, exprs}}, %Env{} = env) do
    Logger.debug("Inferring type of function: #{name}")

    Logger.debug("First call to #{inspect(env.current_signature)}")

    env =
      env
      |> Map.put(:scope, %{})
      |> Map.put(:has_effect, false)
      |> add_args_to_scope(args)

    case infer_block(env, exprs) do
      {:ok, type, env} ->
        type =
          if env.has_effect do
            %T.Effect{type: type}
          else
            type
          end

        {:ok, type}

      error ->
        error
    end
  end

  def infer_block(%Env{} = env, []) do
    Logger.debug("Block is empty.")
    {:ok, nil, env}
  end

  def infer_block(%Env{} = env, [exp]) do
    infer_exp(%Env{} = env, exp)
  end

  def infer_block(%Env{} = env, [exp | exp_list]) do
    case infer_exp(%Env{} = env, exp) do
      {:ok, _type, env} -> infer_block(%Env{} = env, exp_list)
      error -> error
    end
  end

  # Integer literals
  def infer_exp(%Env{} = env, {:integer, _line, integer}) do
    Logger.debug("Integer #{integer} found. Type: Int")
    {:ok, :Int, env}
  end

  # Booleans
  def infer_exp(%Env{} = env, {:boolean, _line, boolean}) do
    Logger.debug("Boolean #{boolean} found. Type: Bool")
    {:ok, :Bool, env}
  end

  # Variables
  def infer_exp(%Env{} = env, {:identifier, _line, name}) do
    type = env.scope[name]

    if type do
      Logger.debug("Variable type found from scope: #{name}:#{type}")
      {:ok, type, env}
    else
      Logger.debug("Variable type not found in scope: #{name}")
      {:error, "Unknown variable: #{name}"}
    end
  end

  # External function calls
  def infer_exp(%Env{} = env, {:ext_call, _line, {m, f, _, type}}) do
    Logger.debug("Return type of ext function #{m}.#{f} specified as #{type}")
    {:ok, type, env}
  end

  # Function calls
  def infer_exp(%Env{} = env, {:call, {name, _line}, args, module}) do
    exp = %{args: args, name: name}
    # module_name = module || Env.current_module(env)
    Logger.debug("Inferring type of function: #{name}")
    infer_args(env, exp, module)
  end

  # Function calls using reference
  # exp has to be a function ref type
  def infer_exp(%Env{} = env, {:call, {exp, _line}, args}) do
    case infer_exp(%Env{} = env, exp) do
      {:ok, %T.FunctionRef{arg_types: arg_types, return_type: type}, env} ->
        case do_infer_args_without_name(env, args) do
          {:ok, ^arg_types, env} ->
            {:ok, type, env}

          {:ok, other_arg_types, _env} ->
            error =
              "Expected function reference to be called with" <>
                " arguments (#{T.Helper.join_list(arg_types)}), but it was called " <>
                "with arguments (#{T.Helper.join_list(other_arg_types)})"

            {:error, error}
        end

      {:ok, type, _} ->
        {:error, "Expected a function reference, but got type: #{type}"}

      error ->
        error
    end
  end

  # =
  def infer_exp(%Env{} = env, {{:=, _}, {:identifier, _line, left}, right}) do
    case infer_exp(%Env{} = env, right) do
      {:ok, type, env} ->
        Logger.debug("Adding variable to scope: #{left}:#{type}")
        env = Env.add_variable_to_scope(env, left, type)
        {:ok, type, env}

      error ->
        error
    end
  end

  # String
  def infer_exp(%Env{} = env, {:string, _line, string_parts}) do
    Enum.reduce_while(string_parts, {:ok, nil, env}, fn
      string, {:ok, _acc_type, acc_env} when is_binary(string) ->
        Logger.debug("String #{string} found. Type: String")
        {:cont, {:ok, :String, acc_env}}

      exp, {:ok, _acc_type, acc_env} ->
        Logger.debug("String interpolation found. Inferring type of expression")

        case infer_exp(acc_env, exp) do
          {:ok, :String, _env} = result ->
            {:cont, result}

          {:ok, other_type, _env} ->
            message =
              "Expression used in string interpolation expected to be String, got #{other_type}"

            {:halt, {:error, message}}

          error ->
            {:halt, error}
        end
    end)
  end

  # List
  def infer_exp(%Env{} = env, {:list, _, exps}) do
    infer_list_exps(env, exps)
  end

  # Tuple
  def infer_exp(%Env{} = env, {:tuple, _, exps}) do
    case do_infer_tuple_exps(exps, env) do
      {:ok, exp_types, env} ->
        {:ok, %T.Tuple{elements: exp_types}, env}

      error ->
        error
    end
  end

  # Record
  def infer_exp(%Env{} = env, {:record, _, name, key_values}) do
    if name do
      # Lookup type of name, ensure it matches.
      Logger.error("Not implemented")
    else
      case do_infer_key_values(key_values, env) do
        {:ok, k_v_types, env} ->
          {:ok, %T.Record{fields: Enum.sort_by(k_v_types, &elem(&1, 0))}, env}

        error ->
          error
      end
    end
  end

  # Map
  # TODO: refactor this when union types are available
  def infer_exp(%Env{} = env, {:map, _, [kv | rest_kvs]}) do
    {key, value} = kv

    with {:ok, key_type, env} <- infer_exp(%Env{} = env, key),
         {:ok, value_type, env} <- infer_exp(%Env{} = env, value) do
      map_type = %T.Map{key_type: key_type, value_type: value_type}

      Enum.reduce_while(rest_kvs, {:ok, map_type, env}, fn {k, v}, {:ok, type, env} ->
        %{key_type: key_type, value_type: value_type} = type

        with {:key, {:ok, ^key_type, env}} <- {:key, infer_exp(%Env{} = env, k)},
             {:value, {:ok, ^value_type, env}} <- {:value, infer_exp(%Env{} = env, v)} do
          {:cont, {:ok, type, env}}
        else
          {:key, {:ok, diff_type, _}} ->
            error = {:error, "Expected map key of type #{key_type}, but got #{diff_type}"}
            {:halt, error}

          {:value, {:ok, diff_type, _}} ->
            error = {:error, "Expected map value of type #{value_type}, but got #{diff_type}"}

            {:halt, error}

          error ->
            {:halt, error}
        end
      end)
    end
  end

  # Function ref
  def infer_exp(%Env{} = env, {:function_ref, _, {module, function_name, arg_types}}) do
    Logger.debug("Inferring type of function: #{function_name}")

    signature = get_function_signature(module || env.module, function_name, arg_types)

    case get_type(module, signature, env) do
      {:ok, type} ->
        type = %T.FunctionRef{arg_types: arg_types, return_type: type}
        {:ok, type, env}

      error ->
        error
    end
  end

  # Atom value
  def infer_exp(%Env{} = env, {:atom, _line, atom}) do
    Logger.debug("Atom value found. Type: #{atom}")
    {:ok, atom, env}
  end

  # if-else expression
  def infer_exp(%Env{} = env, {{:if, _line}, condition, if_block, else_block}) do
    Logger.debug("Inferring an if-else expression")

    case infer_if_else_condition(env, condition) do
      {:ok, :Bool, env} -> infer_if_else_blocks(env, if_block, else_block)
      error -> error
    end
  end

  # case expression
  def infer_exp(%Env{} = env, {{:case, _line}, exp, clauses}) do
    Logger.debug("Inferring a case expression")

    # Check the type of exp.
    # For each clause, ensure all of the patterns return {:ok, env}
    with {:ok, rhs_type, env} <- infer_exp(%Env{} = env, exp),
         {:ok, type, env} <- infer_case_clauses(env, rhs_type, clauses) do
      {:ok, type, env}
    end
  end

  # anonymous function
  def infer_exp(%Env{} = env, {:anonymous_function, _line, args, exps}) do
    Logger.debug("Inferring type of anonymous function")

    env =
      env
      |> Map.put(:scope, %{})
      |> add_args_to_scope(args)

    case infer_block(%Env{} = env, exps) do
      {:ok, return_type, _env} ->
        arg_types = Enum.map(args, fn {_, {:type, _, type}} -> type end)
        type = %T.FunctionRef{arg_types: arg_types, return_type: return_type}
        {:ok, type, env}

      error ->
        error
    end
  end

  def function_ast_signature(module, {:function, _line, {name, args, _type, _exprs}}) do
    arg_types = Enum.map(args, fn {_, {:type, _, type}} -> type end)
    get_function_signature(module, name, arg_types)
  end

  def init_env(ast) do
    %Env{ast: ast, scope: %{}}
  end

  # TODO: made it work, now make it pretty.
  defp infer_case_clauses(env, rhs, clauses) do
    all_rhs_types = Match.expand_unions(rhs)

    result =
      Enum.reduce_while(clauses, {env, [], all_rhs_types}, fn [pattern, block],
                                                              {env, types, unmatched} ->
        case Match.match_case(env, pattern, unmatched) do
          {:ok, env, unmatched} ->
            case infer_block(%Env{} = env, block) do
              {:ok, type, env} -> {:cont, {env, [type | types], unmatched}}
              error -> {:halt, error}
            end

          :error ->
            {:halt, {:error, "Non-matching pattern"}}
        end
      end)

    case result do
      {:error, _} = error ->
        error

      {env, types, []} ->
        type =
          case Enum.uniq(types) do
            [type] -> type
            types -> T.Union.new(types)
          end

        {:ok, type, env}

      {_env, _types, unmatched} ->
        {:error, "Missing pattern: #{Enum.join(unmatched, ", ")}"}
    end
  end

  defp infer_if_else_condition(env, condition) do
    case infer_exp(env, condition) do
      {:ok, :Bool, env} ->
        Logger.debug("if-else condition has return type: Bool")
        {:ok, :Bool, env}

      {_, inferred_type, _env} ->
        Logger.debug("if-else condition has wrong return type: #{inferred_type}")
        {:error, "Wrong type for if condition. Expected: Bool, Got: #{inferred_type}"}
    end
  end

  defp infer_if_else_blocks(env, if_block, else_block) do
    with {:ok, if_type_val, if_env} <- infer_block(env, if_block),
         {:ok, else_type_val, else_env} <- infer_block(if_env, else_block) do
      if if_type_val == else_type_val do
        {:ok, if_type_val, else_env}
      else
        {:ok, T.Union.new([if_type_val, else_type_val]), else_env}
      end
    end
  end

  defp do_infer_key_values(key_values, env) do
    Enum.reduce_while(key_values, {:ok, [], env}, fn {k, v}, {:ok, acc, env} ->
      case infer_exp(%Env{} = env, v) do
        {:ok, type, env} ->
          {:identifier, _, key} = k
          {:cont, {:ok, [{key, type} | acc], env}}

        error ->
          {:halt, error}
      end
    end)
  end

  defp do_infer_tuple_exps(exps, env) do
    Enum.reduce_while(exps, {:ok, [], env}, fn exp, {:ok, acc, env} ->
      case infer_exp(%Env{} = env, exp) do
        {:ok, exp_type, env} ->
          {:cont, {:ok, [exp_type | acc], env}}

        error ->
          {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed_exp_types, env} ->
        {:ok, Enum.reverse(reversed_exp_types), env}

      error ->
        error
    end
  end

  def infer_args(env, exp, module) do
    case do_infer_args(env, exp) do
      {:ok, type_acc, env} ->
        signature = get_function_signature(module || env.module, exp.name, type_acc)

        case get_type(module, signature, env) do
          {:ok, %T.Effect{type: type}} ->
            env = Map.put(env, :has_effect, true)
            {:ok, type, env}

          {:ok, type} ->
            {:ok, type, env}

          error ->
            error
        end

      error ->
        error
    end
  end

  defp infer_list_exps(env, []) do
    {:ok, %T.List{}, env}
  end

  defp infer_list_exps(env, [exp]) do
    case infer_exp(%Env{} = env, exp) do
      {:ok, type, env} -> {:ok, %T.List{type: type}, env}
      error -> error
    end
  end

  defp infer_list_exps(env, [exp | rest]) do
    {:ok, type, env} = infer_exp(%Env{} = env, exp)

    Enum.reduce_while(rest, {:ok, %T.List{type: type}, env}, fn exp, {:ok, acc_type, acc_env} ->
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

  defp do_infer_args(env, exp) do
    Enum.reduce_while(exp.args, {:ok, [], env}, fn arg, {:ok, type_acc, env} ->
      case infer_exp(%Env{} = env, arg) do
        {:ok, type, env} ->
          Logger.debug("Argument of #{exp.name} is type: #{type}")
          {:cont, {:ok, [type | type_acc], env}}

        error ->
          Logger.debug("Argument of #{exp.name} cannot be inferred")
          {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed_types, env} ->
        {:ok, Enum.reverse(reversed_types), env}

      error ->
        error
    end
  end

  # TODO: This can be merged with do_infer_args
  defp do_infer_args_without_name(env, args) do
    Enum.reduce_while(args, {:ok, [], env}, fn arg, {:ok, acc, env} ->
      case infer_exp(%Env{} = env, arg) do
        {:ok, type, env} ->
          Logger.debug("Argument is type: #{type}")
          {:cont, {:ok, [type | acc], env}}

        error ->
          Logger.debug("Argument cannot be inferred")
          {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed_types, env} ->
        {:ok, Enum.reverse(reversed_types), env}

      error ->
        error
    end
  end

  defp add_args_to_scope(env, args) do
    Enum.reduce(args, env, fn {{:identifier, _, name}, {:type, _, type}}, env ->
      Logger.debug("Adding arg type to scope: #{name}:#{type}")
      Env.add_variable_to_scope(env, name, type)
    end)
  end

  defp set_latest_call(env, signature) do
    Map.put(env, :latest_called_function, signature)
  end

  defp get_function_signature(module, function_name, arg_types) do
    %FunctionSignature{module: module, function: to_string(function_name), types: arg_types}
  end

  defp get_type(module, target_signature, env) do
    is_local_call = is_nil(module) or module == env.module_name

    current_signature = env.current_signature

    pid = env.type_checker_pid

    function_dependency =
      if current_signature do
        CodeServer.set_function_dependency(current_signature, target_signature)
      else
        :ok
      end

    case {is_local_call, function_dependency, pid} do
      {true, :ok, pid} when is_pid(pid) ->
        ParallelTypeChecker.get_result(pid, target_signature)

      {true, :ok, nil} ->
        SequentialTypeChecker.get_result(target_signature, env)

      {_, {:error, :cycle_encountered}, _} ->
        {:ok, T.Loop.new()}

      {false, _, _} ->
        CodeServer.get_type(target_signature)
    end
  end
end
