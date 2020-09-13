defmodule Fika.Code do
  alias Fika.{
    Parser,
    TypeChecker,
    ErlTranslate,
    Env
  }

  require Logger

  def load_file(file) do
    case File.read(file) do
      {:ok, str} ->
        load_string(str, file)

      {:error, error} -> IO.puts("Cannot read file: #{inspect error}")
    end
  end

  def load_string(module_str, file) do
    if validate_filename?(file) do
      module_name = file_to_module(file)
      ast = Parser.parse_module(module_str, module_name)
      {:ok, _env} = TypeChecker.check_module(ast, Env.init())
      forms = ErlTranslate.translate(ast, file)
      {:module, module} = result = load_forms(forms, file)
      Logger.debug "Loaded module #{module}"
      result
    else
      {:error, "Invalid filename. Make sure it's something like foo/bar/baz.fi"}
    end
  end

  def load_forms(forms, file) do
    {:ok, module, binary} = :compile.forms(forms)
    :code.load_binary(module, String.to_charlist(file), binary)
  end

  defp validate_filename?(file) do
    String.match?(file, ~r/^([a-z][a-z0-9]*\/)*[a-z][a-z0-9]*.fi/)
  end

  defp file_to_module(file) do
    String.trim_trailing(file, ".fi")
  end
end
