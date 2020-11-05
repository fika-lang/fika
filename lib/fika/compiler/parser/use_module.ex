defmodule Fika.Compiler.Parser.UseModule do
  import NimbleParsec

  alias Fika.Compiler.Parser.{
    Common,
    Helper
  }

  allow_space = parsec({Common, :allow_space})
  require_space = parsec({Common, :require_space})

  module_str =
    ascii_string([?a..?z], 1)
    |> ascii_string([?a..?z, ?_, ?0..?9], min: 0)

  path =
    string("/")
    |> concat(module_str)

  module_path =
    module_str
    |> repeat(path)
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

  defcombinator :use_modules, use_modules
end
