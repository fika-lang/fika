defmodule Fika.Compiler.TypeChecker.Match do
  alias Fika.Compiler.TypeChecker.Types, as: T

  # Returns:
  # {:ok, env, unmatched_types} | :error
  def match_case(env, lhs_ast, rhs_types) when is_list(rhs_types) do
    find_unmatched(env, lhs_ast, rhs_types)
  end

  def match_case(env, lhs_ast, rhs_types) do
    match_case(env, lhs_ast, expand_unions(rhs_types))
  end

  # Returns {:ok, env} | :error
  def match(env, lhs_ast, rhs_type) when is_list(rhs_type) do
    case find_unmatched(env, lhs_ast, rhs_type) do
      {:ok, env, []} -> {:ok, env}
      _ -> :error
    end
  end

  def match(env, lhs_ast, rhs_type) do
    match(env, lhs_ast, expand_unions(rhs_type))
  end

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

  defp find_unmatched(env, lhs_ast, all_rhs_types) do
    find_unmatched(env, lhs_ast, all_rhs_types, [], false)
  end

  defp find_unmatched(_, _, [], _, false) do
    :error
  end

  defp find_unmatched(env, _, [], acc, true) do
    {:ok, env, Enum.reverse(acc)}
  end

  defp find_unmatched(env, lhs_ast, [type | rest], acc, matched?) do
    case do_match_case(env, lhs_ast, type) do
      {:ok, env} ->
        find_unmatched(env, lhs_ast, rest, acc, true)

      {:keep, env} ->
        find_unmatched(env, lhs_ast, rest, [type | acc], true)

      :error ->
        find_unmatched(env, lhs_ast, rest, [type | acc], matched?)
    end
  end

  defp do_match_case_all(env, [], [], status) do
    {status, env}
  end

  defp do_match_case_all(env, [lhs_exp | lhs_exps], [type | rhs_types], status) do
    case do_match_case(env, lhs_exp, type) do
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

  defp do_match_case(env, {:identifier, _, name}, rhs) do
    env =
      update_in(env, [:scope, name], fn
        nil -> rhs
        %T.Union{types: types} -> T.Union.new([rhs | T.Union.to_list(types)])
        type -> T.Union.new([rhs, type])
      end)

    {:ok, env}
  end

  defp do_match_case(env, {:atom, _, lhs_atom}, rhs_atom) when lhs_atom == rhs_atom do
    {:ok, env}
  end

  defp do_match_case(env, {:integer, _, _}, :Int) do
    {:keep, env}
  end

  defp do_match_case(env, {:string, _, _}, :String) do
    {:keep, env}
  end

  defp do_match_case(env, {:tuple, _, lhs_exps}, %T.Tuple{elements: rhs_types})
       when length(lhs_exps) == length(rhs_types) do
    do_match_case_all(env, lhs_exps, rhs_types, nil)
  end

  defp do_match_case(env, {:record, _, _, lhs_k_v}, %T.Record{fields: rhs_k_v}) do
    rhs = Map.new(rhs_k_v)

    # TODO: Use key instead of identifier after fixing GH #65
    Enum.reduce_while(lhs_k_v, {nil, env}, fn {{:identifier, _, lhs_k}, lhs_v}, {status, env} ->
      rhs_v = Map.get(rhs, lhs_k)

      if rhs_v do
        case do_match_case(env, lhs_v, rhs_v) do
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

  defp do_match_case(_, _, _) do
    :error
  end
end
