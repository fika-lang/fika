defmodule Fika.ParserHelper do
  import NimbleParsec

  def to_ast(c, kind) do
    c
    |> line()
    |> byte_offset()
    |> map({Fika.ParserHelper, :put_line_offset, []})
    |> map({Fika.ParserHelper, :do_to_ast, [kind]})
  end


  def put_line_offset({[{result, {line, line_start_offset}}], string_offset}) do
    {result, {line, line_start_offset, string_offset}}
  end

  def do_to_ast({[value], line}, :integer) do
    {:integer, line, value}
  end

  def do_to_ast({[value], line}, :boolean) do
    {:boolean, line, value == "true"}
  end

  def do_to_ast({[condition, true_block, false_block], line}, :exp_if_else) do
    {{:if, line}, condition, true_block, false_block}
  end

  def do_to_ast({[left, bin_op, right | rest], line}, :exp_bin_op) when bin_op in ["+", "-", "*", "/"] do
    new_left = {:call, {String.to_atom(bin_op), line}, [left, right], :kernel}
    do_to_ast({[new_left | rest], line}, :exp_bin_op)
  end

  def do_to_ast({[result], _line}, :exp_bin_op) do
    result
  end

  def do_to_ast({[name], line}, :identifier) do
    {:identifier, line, String.to_atom(name)}
  end

  def do_to_ast({[name, args, type, exps], line}, :function_def) do
    {:identifier, _, name} = name
    {:function, [position: line], {name, args, type, exps}}
  end

  def do_to_ast({[], line}, :return_type) do
    {:type, line, "Nothing"}
  end

  def do_to_ast({[type], _line}, :return_type) do
    type
  end

  def do_to_ast({[name], _line}, :simple_type) do
    name
  end

  def do_to_ast({types, line}, :type) do
    type =
      Enum.reduce(types, "", fn
        {:atom, _l, value}, acc ->
          acc <> ":#{value}"

        type, acc ->
          acc <> type
      end)

    {:type, line, type}
  end

  def do_to_ast({[identifier, type], _line}, :arg) do
    {identifier, type}
  end

  def do_to_ast({[name, args], line}, :local_function_call) do
    {:identifier, _, name} = name
    {:call, {name, line}, args, nil}
  end

  def do_to_ast({[module_alias, name, args], line}, :remote_function_call) do
    {:identifier, _, module_alias} = module_alias
    {:identifier, _, name} = name
    {:call, {name, line}, args, module_alias}
  end

  def do_to_ast({val, line}, :function_ref_call) do
    case val do
      [exp, args] ->
        {:call, {exp, line}, args}
      [val] ->
        val
    end
  end

  def do_to_ast({[identifier, exp], line}, :exp_match) do
    {{:=, line}, identifier, exp}
  end

  def do_to_ast({value, line}, :string) do
    {:string, line, to_string(value)}
  end

  def do_to_ast({result, line}, :exp_list) do
    {:list, line, result}
  end

  def do_to_ast({result, line}, :tuple) do
    result = List.to_tuple(result)
    {:tuple, line, result}
  end

  def do_to_ast({[k, v], _line}, :key_value) do
    {k, v}
  end

  def do_to_ast({[name | key_values], line}, :record) do
    name =
      case name do
        [] -> nil
        [name] -> name
      end

    {:record, line, name, key_values}
  end

  def do_to_ast({ast, line}, :function_ref) do
    case ast do
      [[], function, arg_types] ->
        {:function_ref, line, {nil, value_from_identifier(function), arg_types}}
      [[module], function, arg_types] ->
        {:function_ref, line, {value_from_identifier(module), value_from_identifier(function), arg_types}}
    end
  end

  def do_to_ast({[{:identifier, line, value}], line}, :atom) do
    {:atom, line, value}
  end
  
  defp value_from_identifier({:identifier, _line, value}) do
    value
  end
end
