defmodule Fika.Compiler.TypeChecker.FunctionMatch do
  alias Fika.Compiler.TypeChecker.Types, as: T

  # Given a map of signatures to values and a signature,
  # finds the value for the signature which is a supertype of the second arg.
  def find_by_call(map, signature) when is_map(map) do
    Enum.find_value(map, fn {s, v} ->
      # signature_matches_call?(s, signature)

      if vars = match_signatures(s, signature) do
        {s, v, vars}
      end
    end)
  end

  def find_by_call(_, _), do: nil

  def match_signatures(s1, s2) do
    if s1.module == s2.module && s1.function == s2.function &&
         length(s1.types) == length(s2.types) do
      match_types(s1.types, s2.types, %{})
    end
  end

  def replace_vars({:ok, type}, vars) do
    {:ok, do_replace_vars(type, vars)}
  end

  def replace_vars(error, _) do
    error
  end

  defp do_replace_vars(var, vars) when is_binary(var) do
    vars[var]
  end

  defp do_replace_vars(%T.Union{types: ts}, vars) do
    ts
    |> Enum.map(&do_replace_vars(&1, vars))
    |> T.Union.new()
  end

  defp do_replace_vars(%T.Tuple{elements: ts}, vars) do
    ts = Enum.map(ts, &do_replace_vars(&1, vars))
    %T.Tuple{elements: ts}
  end

  defp do_replace_vars(%T.List{type: t}, vars) do
    %T.List{type: do_replace_vars(t, vars)}
  end

  defp do_replace_vars(%T.Map{key_type: kt, value_type: vt}, vars) do
    %T.Map{
      key_type: do_replace_vars(kt, vars),
      value_type: do_replace_vars(vt, vars)
    }
  end

  defp do_replace_vars(%T.Effect{type: t}, vars) do
    %T.Effect{type: do_replace_vars(t, vars)}
  end

  defp do_replace_vars(type, _) do
    type
  end

  defp match_types([], [], vars) do
    vars
  end

  defp match_types([t1 | t1s], [t2 | t2s], vars) do
    if vars = match_type(t1, t2, vars) do
      match_types(t1s, t2s, vars)
    end
  end

  defp match_type(t1, t2, vars) do
    do_match_subtype(t1, t2, vars)
  end

  defp do_match_subtype(x, y, vars) when is_binary(x) do
    case vars[x] do
      ^y -> vars
      nil -> Map.put(vars, x, y)
      _ -> nil
    end
  end

  defp do_match_subtype(x, y, vars) when x == y do
    vars
  end

  defp do_match_subtype(%T.Union{types: t1s}, t2, vars) do
    Enum.find_value(t1s, fn t1 ->
      do_match_subtype(t1, t2, vars)
    end)
  end

  defp do_match_subtype(%T.Tuple{elements: t1s}, %T.Tuple{elements: t2s}, vars)
       when length(t1s) == length(t2s) do
    do_match_all_subtype(t1s, t2s, vars)
  end

  defp do_match_subtype(_, _, _) do
    nil
  end

  defp do_match_all_subtype([], [], vars) do
    vars
  end

  defp do_match_all_subtype([t1 | t1s], [t2 | t2s], vars) do
    case do_match_subtype(t1, t2, vars) do
      nil -> nil
      vars -> do_match_all_subtype(t1s, t2s, vars)
    end
  end
end
