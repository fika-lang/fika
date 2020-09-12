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

  defp translate_exp({:call, {bin_op, {line, _, _}}, [arg1, arg2], _module}) when bin_op in [:+, :-, :*, :/] do
    {:op, line, bin_op, translate_exp(arg1), translate_exp(arg2)}
  end

  defp translate_exp({:call, {name, {line, _, _}}, args, nil}) do
    {:call, line, {:atom, line, name}, translate_exps(args)}
  end

  defp translate_exp({:call, {name, {line, _, _}}, args, module}) do
    m_f = {:remote, line, {:atom, line, module}, {:atom, line, name}}
    {:call, line, m_f, translate_exps(args)}
  end

  defp translate_exp({:integer, {line, _, _}, value}) do
    {:integer, line, value}
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
end
