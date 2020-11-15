defmodule Fika.Compiler.Parser.UseModule do
  import NimbleParsec

  alias Fika.Compiler.Parser.{
    Common,
    Helper
  }

  allow_space = parsec({Common, :allow_space})
  require_space = parsec({Common, :require_space})
  identifier_str = parsec({Common, :identifier_str})

  path =
    ascii_string([?a..?z, ?_, ?0..?9, ?A..?Z], min: 1)
    |> string("/")

  module_path =
    repeat(path)
    |> concat(identifier_str)
    |> reduce({Enum, :join, [""]})

  use_module =
    ignore(string("use"))
    |> concat(require_space)
    |> concat(module_path)
    |> Helper.to_ast(:use_module)

  use_modules =
    allow_space
    |> concat(use_module)
    |> repeat()

  defcombinator :use_modules, use_modules |> post_traverse(:add_use_modules_context)

  defp add_use_modules_context(_rest, result, _context, _, _) do
    {result, use_modules_map(result)}
  end

  defp use_modules_map(use_modules) do
    Enum.map(use_modules, fn {path, _line} ->
      module_name =
        path
        |> String.split("/")
        |> List.last()

      {module_name, path}
    end)
    |> Map.new()
  end
end
