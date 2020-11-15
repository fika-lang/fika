defmodule Fika.Compiler.Parser.Helper do
  import NimbleParsec

  alias Fika.Compiler.TypeChecker.Types, as: T

  def to_ast(c, kind) do
    c
    |> line()
    |> byte_offset()
    |> map({__MODULE__, :put_line_offset, []})
    |> post_traverse({__MODULE__, :do_to_ast_with_context, [kind]})
  end

  def do_to_ast_with_context(_, [result], context, _, _, kind) do
    if kind in [:remote_function_call, :function_ref] do
      case do_to_ast(result, context, kind) do
        {:error, _} = error ->
          error

        result ->
          {[result], context}
      end
    else
      {[do_to_ast(result, kind)], context}
    end
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

  def do_to_ast({[left, bin_op, right | rest], line}, :exp_bin_op)
      when bin_op in ["+", "-", "*", "/", "|", "&", "<", ">", "<=", ">=", "==", "!="] do
    new_left = {:call, {String.to_atom(bin_op), line}, [left, right], "fika/kernel"}
    do_to_ast({[new_left | rest], line}, :exp_bin_op)
  end

  def do_to_ast({[result], _line}, :exp_bin_op) do
    result
  end

  def do_to_ast({[unary_op, exp], line}, :unary_op)
      when unary_op in ["!", "-"] do
    {:call, {String.to_atom(unary_op), line}, [exp], "fika/kernel"}
  end

  def do_to_ast({[name], line}, :identifier) do
    {:identifier, line, String.to_atom(name)}
  end

  def do_to_ast({[name], line}, :module_name) do
    {:module_name, line, name}
  end

  def do_to_ast({[name, args, type, exps], line}, :function_def) do
    {:identifier, _, name} = name
    {:function, [position: line], {name, args, type, exps}}
  end

  def do_to_ast({[], line}, :return_type) do
    {:type, line, :Nothing}
  end

  def do_to_ast({[type], _line}, :return_type) do
    type
  end

  def do_to_ast({[{_, _, inner_type}], _line}, :list_type) when is_struct(inner_type) do
    %T.List{type: inner_type}
  end

  def do_to_ast({[inner_type], _line}, :list_type) do
    %T.List{type: inner_type}
  end

  def do_to_ast({inner_types, _line}, :tuple_type) do
    %T.Tuple{elements: inner_types}
  end

  def do_to_ast({[key_type, value_type], _line}, :map_type) do
    %T.Map{key_type: key_type, value_type: value_type}
  end

  def do_to_ast({[key, value], _line}, :record_field) do
    {String.to_atom(key), value}
  end

  def do_to_ast({fields, _line}, :record_type) do
    %T.Record{fields: fields}
  end

  def do_to_ast({[{:atom, _, atom}], _line}, :atom_type) do
    atom
  end

  def do_to_ast({types, _line}, :function_type) do
    arg_types = types |> Keyword.take([:arg_type]) |> Keyword.values()
    return_type = Keyword.get(types, :return_type)

    %T.FunctionRef{arg_types: arg_types, return_type: return_type}
  end

  def do_to_ast({types, _line}, :union_type) do
    T.Union.new(types)
  end

  def do_to_ast({[{_, _, type}], line}, :type) when is_struct(type) do
    {:type, line, type}
  end

  def do_to_ast({[type], line}, :type) do
    {:type, line, type}
  end

  def do_to_ast({[identifier, type], _line}, :arg) do
    {identifier, type}
  end

  def do_to_ast({[name, args], line}, :local_function_call) do
    {:identifier, _, name} = name
    {:call, {name, line}, args, nil}
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
    str =
      value
      |> Enum.chunk_by(&is_tuple/1)
      |> Enum.flat_map(fn
        [h | _tail] = interpolations when is_tuple(h) -> interpolations
        charlist -> [to_string(charlist)]
      end)

    {:string, line, str}
  end

  def do_to_ast({result, line}, :exp_list) do
    {:list, line, result}
  end

  def do_to_ast({result, line}, :tuple) do
    {:tuple, line, result}
  end

  def do_to_ast({key_values, line}, :map) do
    {:map, line, key_values}
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

  def do_to_ast({[{:identifier, line, value}], line}, :atom) when value in [true, false] do
    {:boolean, line, value}
  end

  def do_to_ast({[{:identifier, line, value}], line}, :atom) do
    {:atom, line, value}
  end

  def do_to_ast({[value], line}, :use_module) do
    {value, line}
  end

  def do_to_ast({ast, line}, context, :function_ref) do
    case ast do
      [[], function, arg_types] ->
        {:function_ref, line, {nil, value_from_identifier(function), arg_types}}

      [[module_alias], function, arg_types] ->
        if module = expand_module(module_alias, context) do
          {:function_ref, line,
           {value_from_identifier(module), value_from_identifier(function), arg_types}}
        else
          {:module_name, _line, module_name} = module_alias
          {:error, "Unknown module #{module_name}"}
        end
    end
  end

  def do_to_ast({[module_alias, name, args], line}, context, :remote_function_call) do
    if module = expand_module(module_alias, context) do
      {:identifier, _, module} = module
      {:identifier, _, name} = name
      {:call, {name, line}, args, module}
    else
      {:module_name, _line, module_name} = module_alias
      {:error, "Unknown module #{module_name}"}
    end
  end

  defp value_from_identifier({:identifier, _line, value}) do
    value
  end

  def to_atom([value]), do: String.to_atom(value)

  def tag(value, tag) do
    {tag, value}
  end

  defp expand_module({:module_name, line, module}, context) do
    module =
      if module == "fika/kernel" do
        "fika/kernel"
      else
        context[module]
      end

    module && {:identifier, line, module}
  end
end
