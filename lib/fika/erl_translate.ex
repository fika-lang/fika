defmodule Fika.ErlTranslate do
  def translate({:module, module_name, functions}, file) do
    line = 1
    file = String.to_charlist(file)

    module = [
      {:attribute, line, :file, {file, line}},
      {:attribute, line, :module, String.to_atom(module_name)}
    ]

    {exports, function_declaration} = to_forms(functions)

    module ++ exports ++ function_declaration
  end

  def translate_expression(exp) do
    translate_exp(exp)
  end

  defp to_forms(functions) do
    Enum.reduce(functions, {[], []}, fn function, {exports, decs} ->
      {:function, [position: {line, _, _}], {name, args, _type, exps}} = function
      arity = length(args)
      export = {:attribute, line, :export, [{name, arity}]}
      dec = {:function, line, name, arity, [translate_clauses(args, line, exps)]}
      {[export | exports], [dec | decs]}
    end)
  end

  defp translate_clauses(args, line, exps) do
    {:clause, line, translate_exps(args), [], translate_exps(exps)}
  end

  defp translate_exps(exps) do
    Enum.map(exps, &translate_exp/1)
  end

  defp translate_exp({:call, {bin_op, {line, _, _}}, [arg1, arg2], _module})
       when bin_op in [:+, :-, :*, :/] do
    {:op, line, bin_op, translate_exp(arg1), translate_exp(arg2)}
  end

  defp translate_exp({:call, {:!, {line, _, _}}, [arg], _module}) do
    {:op, line, :not, translate_exp(arg)}
  end

  defp translate_exp({:call, {:-, {line, _, _}}, [arg], _module}) do
    {:op, line, :-, translate_exp(arg)}
  end

  defp translate_exp({:call, {:|, {line, _, _}}, [arg1, arg2], _module}) do
    {:op, line, :or, translate_exp(arg1), translate_exp(arg2)}
  end

  defp translate_exp({:call, {:&, {line, _, _}}, [arg1, arg2], _module}) do
    {:op, line, :and, translate_exp(arg1), translate_exp(arg2)}
  end

  defp translate_exp({:call, {name, {line, _, _}}, args, nil}) do
    {:call, line, {:atom, line, name}, translate_exps(args)}
  end

  defp translate_exp({:call, {name, {line, _, _}}, args, module}) do
    m_f = {:remote, line, {:atom, line, module}, {:atom, line, name}}
    {:call, line, m_f, translate_exps(args)}
  end

  # Call function ref using an identifier
  defp translate_exp({:call, {identifier, {line, _, _}}, args}) do
    {:call, line, translate_exp(identifier), translate_exps(args)}
  end

  defp translate_exp({:integer, {line, _, _}, value}) do
    {:integer, line, value}
  end

  defp translate_exp({:boolean, {line, _, _}, value}) do
    {:atom, line, value}
  end

  defp translate_exp({:atom, {line, _, _}, value}) do
    {:atom, line, value}
  end

  defp translate_exp({{:=, {line, _, _}}, pattern, exp}) do
    {:match, line, translate_exp(pattern), translate_exp(exp)}
  end

  defp translate_exp({:identifier, {line, _, _}, name}) do
    {:var, line, name}
  end

  defp translate_exp({{:identifier, {line, _, _}, name}, {:type, _, _}}) do
    {:var, line, name}
  end

  defp translate_exp({:string, {line, _, _}, [value]}) when is_binary(value) do
    {:string, line, String.to_charlist(value)}
  end

  defp translate_exp({:string, {line, _, _}, str_elements}) do
    translated_exps =
      str_elements
      |> Enum.map(fn
        value when is_binary(value) -> {:string, line, String.to_charlist(value)}
        exp -> translate_exp(exp)
      end)
      |> Enum.map(&{:bin_element, line, &1, :default, :default})

    {:bin, line, translated_exps}
  end

  defp translate_exp({:list, {line, _, _}, value}) do
    do_translate_list(value, line)
  end

  defp translate_exp({:tuple, {line, _, _}, value}) do
    {:tuple, line, translate_exps(value)}
  end

  defp translate_exp({:record, {line, _, _}, name, k_vs}) do
    k_vs =
      Enum.map(k_vs, fn {{:identifier, {l, _, _}, k}, v} ->
        {:map_field_assoc, l, {:atom, l, k}, translate_exp(v)}
      end)

    k_vs = add_record_meta(k_vs, name, line)

    {:map, line, k_vs}
  end

  defp translate_exp({:function_ref, {line, _, _}, {module, function, arg_types}}) do
    arity = length(arg_types)

    f =
      if module do
        {:function, {:atom, line, module}, {:atom, line, function}, {:integer, line, arity}}
      else
        {:function, function, arity}
      end

    {:fun, line, f}
  end

  defp translate_exp({{:if, {line, _, _}}, condition, if_block, else_block}) do
    {
      :case,
      line,
      translate_exp(condition),
      [
        {:clause, line, [{:atom, line, true}], [], translate_exps(if_block)},
        {:clause, line, [{:atom, line, false}], [], translate_exps(else_block)}
      ]
    }
  end

  defp add_record_meta(k_vs, name, line) do
    name =
      if name do
        {:atom, 0, String.to_atom(name)}
      else
        {nil, 0}
      end

    [{:map_field_assoc, line, {:atom, 0, :__record__}, name} | k_vs]
  end

  defp do_translate_list([head | rest], line) do
    {:cons, line, translate_exp(head), do_translate_list(rest, line)}
  end

  defp do_translate_list([], line) do
    {nil, line}
  end
end
