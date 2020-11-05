defmodule Fika.Compiler.Parser do
  import NimbleParsec

  alias Fika.Compiler.Parser.{
    Common,
    FunctionDef,
    UseModule
  }

  allow_space = parsec({Common, :allow_space})
  function_defs = parsec({FunctionDef, :function_defs})
  use_modules = parsec({UseModule, :use_modules})

  module =
    tag(use_modules, :use_modules)
    |> post_traverse(:add_use_modules_context)
    |> tag(function_defs, :function_defs)
    |> concat(allow_space)
    |> eos()

  def parse_module(str) do
    case parse(str) do
      {:ok, ast, _, _, _, _} ->
        {:ok, ast}

      {:error, message, _, %{}, {line, offset}, column} ->
        {:error, {line, offset, column}, message}
    end
  end

  defp add_use_modules_context(_rest, result, _context, _, _) do
    {result, use_modules_map(result[:use_modules])}
  end

  defp use_modules_map(use_modules) do
    Enum.map(use_modules, fn {path, _line} ->
      module_name =
        path
        |> String.split("/")
        |> List.last()
        |> String.to_atom()

      {module_name, String.to_atom(path)}
    end)
    |> Map.new()
  end

  defparsec :parse, module
end
