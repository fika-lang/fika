defmodule Fika.Compiler.PathHelper do
  def path_to_module(path, root \\ "") do
    path
    |> Path.relative_to(root)
    |> Path.rootname()
    |> String.replace("/", ".")
    |> String.to_atom()
  end

  def module_to_path(module, root \\ "") do
    path =
      module
      |> to_string()
      |> String.replace(".", "/")
      |> Kernel.<>(".fi")

    Path.join(root, path)
  end
end
