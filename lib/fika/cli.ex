defmodule Fika.Cli do
  use Bakeware.Script

  require Logger

  @impl Bakeware.Script
  def main(args) do
    parse_args(args)
  end

  defp parse_args([]) do
    IO.puts("""
    Usage:
      fika start <directory>
        Starts the router.fi file inside <directory>.

      fika exec [<module> [--function <function_call>]]
        Executes the function call <function_call> inside the module <module>.

        Options:
          <module>: The module which defines the called function. Defaults to 'main'.
          -f | --function: The function call that should be executed. Defaults to 'start()'.
    """)
  end

  defp parse_args(["exec" | rest]) do
    options = [
      strict: [function: :string],
      aliases: [f: :function]
    ]

    {opts, rest} = OptionParser.parse!(rest, options)

    module = List.first(rest) || "main"
    function = opts[:function] || "start()"

    {:ok, _} = Fika.Code.load_module(module)

    fn_not_found_msg = "Function #{function} not found."

    try do
      Logger.debug("Calling :#{module}.#{function}")
      {result, _binding} = Code.eval_string(~s':"#{module}".#{function}')
      # TODO: This currently prints terms in Elixir. We should print Fika terms.
      result |> inspect() |> IO.puts()
    rescue
      UndefinedFunctionError ->
        IO.puts(fn_not_found_msg)
        System.halt(2)
    end
  end

  defp parse_args(["start" | rest]) do
    path = List.first(rest)

    if path do
      File.cd!(path)
    end

    if not File.exists?("router.fi") do
      raise "cannot start webserver: file 'router.fi' not found in directory '#{path}'"
    end

    {:ok, _} = Fika.Router.start(nil, nil)

    IO.puts("Press Ctrl+C to exit")
    :timer.sleep(:infinity)
  end
end
