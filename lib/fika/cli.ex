defmodule Fika.Cli do
  use Bakeware.Script

  require Logger

  @impl Bakeware.Script
  def main(args) do
    parse_args(args)
  end

  defp parse_args([]) do
    :timer.sleep(:infinity)
  end

  defp parse_args(["exec" | rest]) do
    options = [
      strict: [function: :string],
      aliases: [f: :function]
    ]

    {opts, rest} = OptionParser.parse!(rest, options)

    main_file = List.first(rest) || "main.fi"
    function = opts[:function] || "main.start()"

    {:module, module} = Fika.Code.load_file(main_file)
    Logger.debug("Calling :#{module}.#{function}")
    {result, _binding} = Code.eval_string(":\"#{module}\".#{function}")
    IO.inspect(result)
  end

  defp parse_args(["start" | rest]) do
    path = List.first(rest)

    if path do
      File.cd!(path)
    end

    if not File.exists?("router.fi") do
      raise "cannot start webserver: file 'router.fi' not found in directory '#{path}'"
    end

    case Fika.Application.start(:permanent, port: 6060) do
      {:ok, pid} when is_pid(pid) -> :timer.sleep(:infinity)
      {:error, _} -> :error
    end
  end
end
