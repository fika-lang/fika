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
      first_pass: false,
      scope: %{}
    ]

    def add_variable_to_scope(env, variable, type) do
      %{env | scope: put_in(env.scope, [variable], type)}
    end

    def update_scope(env, variable, update_fn) do
      %{env | scope: update_in(env.scope, [variable], update_fn)}
    end

    def reset_scope_and_set_signature(
          %__MODULE__{} = env,
          {:function, _, {_name, args, _type, _}} = ast
        ) do
      current_signature = Fika.Compiler.TypeChecker.function_ast_signature(env.module, ast)

      %{
        env
        | scope: %{},
          has_effect: false,
          current_signature: current_signature,
          latest_called_function: if(env.first_pass, do: env.current_signature),
          first_pass: false
      }
      |> add_args_to_scope(args)
    end

    def reset_scope_and_set_signature(env, {:anonymous_function, _line, args, _}) do
      %{env | scope: %{}}
      |> add_args_to_scope(args)
    end

    def reset_scope_and_set_signature(env, _ast), do: env

    defp add_args_to_scope(env, args) do
      Enum.reduce(args, env, fn {{:identifier, _, name}, {:type, _, type}}, env ->
        Logger.debug("Adding arg type to scope: #{name}:#{type}")
        Env.add_variable_to_scope(env, name, type)
      end)
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
        unwrap_type(env, expected_type, inferred_type)

      error ->
        error
    end
  end

  defp unwrap_type(
         %Env{current_signature: current_signature},
         wrapped_expected_type,
         wrapped_inferred_type
       ) do
    is_top_level_function = CodeServer.check_cycle(current_signature) == :ok

    expected_type = do_unwrap_type(wrapped_expected_type)
    inferred_type = do_unwrap_type(wrapped_inferred_type)

    cond do
      is_top_level_function and T.Loop.is_loop(expected_type) ->
        {:error, "Top level function cannot be a loop"}

      is_top_level_function and T.Loop.is_loop(inferred_type) and
          inferred_type.type == expected_type ->
        {:ok, expected_type}

      T.Loop.equals?(expected_type, inferred_type) ->
        {:ok, %{expected_type | is_empty_loop: false}}

      match?(^expected_type, inferred_type) ->
        {:ok, expected_type}

      true ->
        {:error, "Expected type: #{expected_type}, got: #{inferred_type}"}
    end
  end

  defp do_unwrap_type(%T.Union{types: union_types}) do
    case Enum.split_with(union_types, &match?(%T.Loop{}, &1)) do
      {[], union_types} ->
        T.Union.new(union_types)

      {loops, union_types} ->
        left_union =
          loops |> Enum.reject(&T.Loop.is_empty_loop/1) |> Enum.map(& &1.type) |> T.Union.new()

        if Enum.empty?(union_types) do
          %T.Loop{is_empty_loop: false, type: T.Union.new(left_union)}
        else
          %T.Loop{is_empty_loop: false, type: T.Union.new([left_union, union_types])}
        end
    end
  end

  defp do_unwrap_type(%T.Effect{type: t}), do: %T.Effect{type: do_unwrap_type(t)}
  defp do_unwrap_type(t), do: t

  # Given the AST of a function definition, this function infers the
  # return type of the body of the function.
  def infer({:function, _line, {_name, _args, _type, exprs}} = ast, %Env{} = env) do
    env = Env.reset_scope_and_set_signature(env, ast)
    Logger.debug("Inferring type of function: #{env.current_signature}")

    with :ok <-
           CodeServer.set_function_dependency(env.latest_called_function, env.current_signature),
         {:ok, type, env} <-
           infer_block(env, exprs) do
      type =
        if env.has_effect do
          %T.Effect{type: type}
        else
          type
        end

      {:ok, do_unwrap_type(type)}
    else
      {:error, :cycle_encountered} ->
        {:ok, T.Loop.new()}

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
  def infer_exp(%Env{} = env, {:anonymous_function, _line, args, exps} = ast) do
    Logger.debug("Inferring type of anonymous function")

    env = Env.reset_scope_and_set_signature(env, ast)

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
            1

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
