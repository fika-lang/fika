defmodule TestParser do
  import NimbleParsec

  alias Fika.Parser.{
    Common,
    Types,
    Expressions,
    FunctionDef
  }

  exp = parsec({Expressions, :exp})
  exps = parsec({Expressions, :exps})
  function_def = parsec({FunctionDef, :function_def})
  allow_space = parsec({Common, :allow_space})
  parse_type = parsec({Types, :parse_type})

  @vertical_space ["\n", "\r"]
  @horizontal_space ["\s", "\t"]
  @space @vertical_space ++ @horizontal_space ++ ["# Dummy comment\n"]

  def h_space(), do: do_space(@horizontal_space)
  def space(), do: do_space(@space)

  # Returns a random combination of space symbols which is
  # guaranteed to contain at leat one occurence of any of them
  defp do_space(symbols, length \\ 5) do
    n = :rand.uniform(length)
    more = for _ <- 1..n, do: Enum.random(symbols)

    symbols
    |> Kernel.++(more)
    |> Enum.shuffle()
    |> Enum.join("")
  end

  def expression!(str) do
    {:ok, [result], _rest, _context, _line, _byte_offset} = expression(str)
    result
  end

  def function_def!(str) do
    {:ok, [result], _rest, _context, _line, _byte_offset} = function_def(str)
    result
  end

  defparsec :expression, exp |> concat(allow_space) |> eos()
  defparsec :function_def, function_def
  defparsec :type_str, parse_type |> concat(allow_space) |> eos()
  defparsec :exps, exps |> concat(allow_space) |> eos()
end
