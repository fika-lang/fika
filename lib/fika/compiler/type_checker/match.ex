defmodule Fika.Compiler.TypeChecker.Match do
  alias Fika.Compiler.TypeChecker.Types, as: T

  # Returns:
  # {:ok, env, unmatched_types} | :error
  def match_case(env, lhs_ast, rhs_type) do
    find_unmatched(env, lhs_ast, rhs_type)
  end

  # Returns {:ok, env} | {:error, string}
  def match(env, lhs_ast, rhs_type) do
    do_match(env, lhs_ast, rhs_type)
  end

  # defp find_unmatched(env, {:identifier, _, name}, rhs) do
  # update_in(env, [:scope, name], fn)
  # {:ok, put_in(env, [:scope, name], rhs), []}
  # end
  defp find_unmatched(env, lhs_ast, rhs) do
    all_rhs_types = expand_unions(rhs)
    find_unmatched(env, lhs_ast, all_rhs_types, [], false)
  end

  defp find_unmatched(_, _, [], _, false) do
    :error
  end

  defp find_unmatched(env, _, [], acc, true) do
    {:ok, env, Enum.reverse(acc)}
  end

  defp find_unmatched(env, lhs_ast, [type | rest], acc, matched?) do
    case do_match_case_new(env, lhs_ast, type) do
      {:ok, env} ->
        # {:ok, env, acc ++ rest}
        find_unmatched(env, lhs_ast, rest, acc, true)

      {:keep, env} ->
        find_unmatched(env, lhs_ast, rest, [type | acc], true)

      # {:ok, env, acc ++ [type | rest]}
      :error ->
        find_unmatched(env, lhs_ast, rest, [type | acc], matched?)
    end
  end

  defp do_match_case_all(env, [], [], status) do
    {status, env}
  end

  defp do_match_case_all(env, [lhs_exp | lhs_exps], [type | rhs_types], status) do
    case do_match_case_new(env, lhs_exp, type) do
      :error ->
        :error

      {new_status, env} ->
        status =
          cond do
            new_status == :ok && status in [:ok, nil] -> :ok
            new_status == :keep -> :keep
          end

        do_match_case_all(env, lhs_exps, rhs_types, status)
    end
  end

  defp do_match_case_new(env, {:identifier, _, name}, rhs) do
    env =
      update_in(env, [:scope, name], fn
        nil -> rhs
        %T.Union{types: types} -> T.Union.new([rhs | T.Union.to_list(types)])
        type -> T.Union.new([rhs, type])
      end)

    {:ok, env}
  end

  defp do_match_case_new(env, {:atom, _, lhs_atom}, rhs_atom) when lhs_atom == rhs_atom do
    {:ok, env}
  end

  defp do_match_case_new(env, {:integer, _, _}, :Int) do
    {:keep, env}
  end

  defp do_match_case_new(env, {:tuple, _, lhs_exps}, %T.Tuple{elements: rhs_types})
       when length(lhs_exps) == length(rhs_types) do
    do_match_case_all(env, lhs_exps, rhs_types, nil)
  end

  defp do_match_case_new(env, {:record, _, _, lhs_k_v}, %T.Record{fields: rhs_k_v}) do
    # rhs_keys = Enum.map(rhs_k_v, fn {k, _} -> k end)
    # all_keys_present =
    # Enum.all?(lhs_k_v, fn {k, _} ->
    # k_v in rhs_keys
    # end)

    rhs = Map.new(rhs_k_v)
    # Enum.reduce(rhs_k_v, %{}, fn {{:identifier, _, rhs_k}, rhs_v}, acc ->
    # Map.put(acc, rhs_k, rhs_v)
    # end)

    # TODO: Use key instead of identifier after fixing GH #65
    Enum.reduce_while(lhs_k_v, {nil, env}, fn {{:identifier, _, lhs_k}, lhs_v}, {status, env} ->
      rhs_v = Map.get(rhs, lhs_k)

      if rhs_v do
        case do_match_case_new(env, lhs_v, rhs_v) do
          :error ->
            {:halt, :error}

          {new_status, env} ->
            status =
              cond do
                new_status == :ok && status in [:ok, nil] -> :ok
                new_status == :keep -> :keep
              end

            {:cont, {status, env}}
        end
      else
        {:halt, :error}
      end
    end)
  end

  defp do_match_case_new(_, _, _) do
    :error
  end

  #defp do_match_case(env, {:identifier, _, name}, rhs) do
    #{:ok, put_in(env, [:scope, name], rhs), nil}
  #end

  #defp do_match_case(env, {:integer, _, _}, :Int) do
    #{:ok, env, :Int}
  #end

  #defp do_match_case(env, {:atom, _, lhs_atom}, rhs_atom) when lhs_atom == rhs_atom do
    #{:ok, env, nil}
  #end

  #defp do_match_case(env, lhs_exp, %T.Union{types: rhs_types}) do
    #case do_match_case_list_any(T.Union.to_list(rhs_types), lhs_exp, env, []) do
      #{:ok, env, []} ->
        #{:ok, env, nil}

      #{:ok, env, [x]} ->
        #{:ok, env, x}

      #{:ok, env, list} ->
        #{:ok, env, T.Union.new(list)}

      #:error ->
        #:error
    #end
  #end

  #defp do_match_case(env, {:tuple, _, lhs_exps}, %T.Tuple{elements: rhs_types})
       #when length(lhs_exps) == length(rhs_types) do
    #case do_match_case_list_all(rhs_types, lhs_exps, env, []) do
      #{:ok, env, list} ->
        #unmatched =
          #if Enum.all?(list, &is_nil(&1)) do
            #nil
          #else
            #list =
              #Enum.map(list, fn
                #nil -> :_
                #x -> x
              #end)

            #%T.Tuple{elements: list}
          #end

        #{:ok, env, unmatched}

      #:error ->
        #:error
    #end
  #end

  #defp do_match_case(_, _, _) do
    #:error
  #end

  defp do_match(env, {:atom, _, atom}, rhs) when rhs == atom do
    {:ok, env}
  end

  defp do_match(env, {:identifier, _line, name}, rhs) do
    {:ok, put_in(env, [:scope, name], rhs)}
  end

  defp do_match(env, {:tuple, _, lhs_exps}, %T.Tuple{elements: elements})
       when length(lhs_exps) == length(elements) do
    Enum.reduce_while(elements, {env, lhs_exps}, fn element, {env, [exp | exps]} ->
      case do_match(env, exp, element) do
        {:ok, env} ->
          if exps == [] do
            {:cont, {:ok, env}}
          else
            {:cont, {env, exps}}
          end

        error ->
          {:halt, error}
      end
    end)
  end

  defp do_match(env, {:record, _, _, key_values}, %T.Record{fields: fields})
       when length(key_values) == length(fields) do
    Enum.reduce_while(fields, {env, key_values}, fn
      {r_key, rhs_type}, {env, [{{:identifier, _, l_key}, lhs_exp} | exps]} when r_key == l_key ->
        case do_match(env, lhs_exp, rhs_type) do
          {:ok, env} ->
            if exps == [] do
              {:cont, {:ok, env}}
            else
              {:cont, {env, exps}}
            end

          error ->
            {:halt, error}
        end

      {{:identifier, _, r_key}, _}, {_, [{{:identifier, _, l_key}, _} | _]} ->
        {:error, "Field #{r_key} does not match the key on the left hand side: #{l_key}"}
    end)
  end

  defp do_match(_env, _, rhs_type) do
    {:error, "Type #{rhs_type} cannot match left hand side value."}
  end

  #defp do_match_case_list_all([], [], env, acc) do
    #{:ok, env, acc}
  #end

  #defp do_match_case_list_all([type | rhs_types], [exp | lhs_exps], env, acc) do
    #case do_match_case(env, exp, type) do
      #{:ok, env, unmatched} ->
        #acc = acc ++ [unmatched]
        #do_match_case_list_all(rhs_types, lhs_exps, env, acc)

      #:error ->
        #:error
    #end
  #end

  #defp do_match_case_list_any([], _, _, _) do
    #:error
  #end

  #defp do_match_case_list_any([type | rhs_types], lhs_exp, env, acc) do
    #case do_match_case(env, lhs_exp, type) do
      #{:ok, env, nil} ->
        #{:ok, env, acc ++ rhs_types}

      #{:ok, env, unmatched} ->
        #{:ok, env, acc ++ [unmatched | rhs_types]}

      #:error ->
        #acc = acc ++ [type]
        #do_match_case_list_any(rhs_types, lhs_exp, env, acc)
    #end
  #end

  def expand_unions(%T.Union{types: types}) do
    Enum.flat_map(types, &expand_unions(&1))
  end

  def expand_unions(%T.Tuple{elements: types}) do
    types
    |> do_expand_all()
    |> Enum.map(&%T.Tuple{elements: &1})
  end

  def expand_unions(%T.Record{fields: key_values}) do
    {keys, values} =
      Enum.reduce(key_values, {[], []}, fn {k, v}, {ks, vs} ->
        {[k | ks], [v | vs]}
      end)

    keys = Enum.reverse(keys)
    values = Enum.reverse(values)

    values
    |> do_expand_all()
    |> Enum.map(fn values ->
      fields = Enum.zip(keys, values)
      %T.Record{fields: fields}
    end)
  end

  def expand_unions(x) do
    [x]
  end

  def do_expand_all([]) do
    [[]]
  end

  def do_expand_all([type | rest]) do
    branches = expand_unions(type)
    next_branches = do_expand_all(rest)

    Enum.flat_map(branches, fn branch ->
      Enum.map(next_branches, fn next_branch ->
        [branch | next_branch]
      end)
    end)
  end
end
