defmodule Fika.Deploy do
  def copy_files(args) do
    path = "_build/#{Mix.env()}/rel/bakeware/fika"

    File.cp!(path, "./fika")
    IO.puts("Fika executable available at #{File.cwd!()}/fika")
    args
  end
end
