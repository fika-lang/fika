defmodule TestParser do
  import NimbleParsec

  alias Fika.Parser.{
    Common,
    Types,
    Expressions,
    FunctionDef,
    UseModule
  }

  exp = parsec({Expressions, :exp})
  exps = parsec({Expressions, :exps})
  function_defs = parsec({FunctionDef, :function_defs})
  function_def = parsec({FunctionDef, :function_def})
  use_modules = parsec({UseModule, :use_modules})
  allow_space = parsec({Common, :allow_space})
  parse_type = parsec({Types, :parse_type})

  @vertical_space ["\n", "\r"]
  @horizontal_space ["\s", "\t"]
  @space @vertical_space ++ @horizontal_space ++ ["# Dummy comment\n"]

  # Returns a random combination of horizontal space symbols
  def h_space(length \\ 5), do: do_space(@horizontal_space, length)

  # Returns a random combination of space symbols (both horizontal and vertical)
  def space(length \\ 5), do: do_space(@space, length)

  # Returns a random combination of space symbols which is
  # guaranteed to contain at leat one occurence of any of them
  defp do_space(symbols, length) do
    n = :rand.uniform(length)
    more = for _ <- 1..n, do: Enum.random(symbols)

    symbols
    |> Kernel.++(more)
    |> Enum.shuffle()
    |> Enum.join("")
  end

  def expression!(str), do: do_parse(&expression/1, str)

  def function_def!(str), do: do_parse(&function_def/1, str)

  def type_str!(str), do: do_parse(&type_str/1, str)

  defp do_parse(parser, str) do
    {:ok, [result], _rest, _context, _line, _byte_offset} = parser.(str)
    result
  end

  defparsec :expression, exp |> concat(allow_space) |> eos()
  defparsec :function_def, function_def

  defparsec :type_str,
            parse_type
            |> concat(allow_space)
            |> eos()

  defparsec :exps, exps |> concat(allow_space) |> eos()

  defparsec :function_defs,
            function_defs |> concat(allow_space) |> eos() |> map({:fetch_function_def, []})

  defparsec :use_modules, use_modules |> concat(allow_space) |> eos()

  defp fetch_function_def({:function_defs, [function_def]}) do
    function_def
  end
end
