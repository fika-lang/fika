defmodule Fika.Deploy do
  def copy_files(args) do
    path = "_build/#{Mix.env()}/rel/bakeware/fika"

    File.cp!(path, "./fika")
    args
  end
end
