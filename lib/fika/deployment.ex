defmodule Fika.Deployment do
  def copy_files(args) do
    path = "_build/#{Mix.env()}/rel/bakeware/fika"

    File.mkdir_p!("./dist")

    File.cp!(path, "./dist/fika")
    IO.puts("Fika executable available at #{File.cwd!()}/dist/fika")
    args
  end
end
