defmodule Fika.Compiler.Parser.Common do
  import NimbleParsec

  alias Fika.Compiler.Parser.Helper

  keyword =
    choice([
      string("fn"),
      string("do"),
      string("end"),
      string("if"),
      string("else")
    ])

  horizontal_space =
    choice([
      string("\s"),
      string("\t")
    ])

  comment =
    string("#")
    |> repeat(utf8_char(not: ?\n))
    |> string("\n")

  vertical_space =
    choice([
      string("\r"),
      string("\n")
    ])

  space =
    choice([vertical_space, horizontal_space, comment])
    |> label("space or newline")

  require_space =
    space
    |> times(min: 1)
    |> ignore()

  allow_horizontal_space =
    horizontal_space
    |> repeat()
    |> ignore()

  allow_space =
    space
    |> repeat()
    |> ignore()

  identifier_str =
    ascii_string([?a..?z], 1)
    |> ascii_string([?a..?z, ?_, ?0..?9], min: 0)
    |> reduce({Enum, :join, [""]})
    |> label("snake_case string")

  module_name =
    identifier_str
    |> label("module name")
    |> Helper.to_ast(:module_name)

  identifier =
    lookahead_not(keyword)
    |> concat(identifier_str)
    |> label("identifier")
    |> Helper.to_ast(:identifier)

  atom =
    ignore(string(":"))
    |> concat(identifier)
    |> label("atom")
    |> Helper.to_ast(:atom)

  defcombinator :allow_space, allow_space
  defcombinator :require_space, require_space
  defcombinator :identifier_str, identifier_str
  defcombinator :identifier, identifier
  defcombinator :module_name, module_name
  defcombinator :allow_horizontal_space, allow_horizontal_space
  defcombinator :atom, atom
end
