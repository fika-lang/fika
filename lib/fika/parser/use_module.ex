defmodule Fika.Parser.UseModule do
  import NimbleParsec

  alias Fika.Parser.{
    Common,
    Helper
  }

  allow_space = parsec({Common, :allow_space})
  require_space = parsec({Common, :require_space})

  module_str =
    ascii_string([?a..?z], 1)
    |> ascii_string([?a..?z, ?_, ?0..?9], min: 0)

  module_name =
    module_str
    |> reduce({Enum, :join, [""]})

  path =
    module_str
    |> string("/")
    |> repeat()
    |> reduce({Enum, :join, [""]})

  module_path =
    path
    |> concat(module_name)

  use_modules =
    allow_space
    |> ignore(string("use"))
    |> concat(require_space)
    |> concat(module_path)
    |> Helper.to_ast(:use_module)
    |> times(min: 1)
    |> Helper.to_ast(:use_modules)

  defcombinator :use_modules, use_modules
end
