defmodule Fika.Compiler.ProjectCompilerTest do
  use ExUnit.Case, async: false

  alias Fika.Compiler.{
    ProjectCompiler,
    Cache
  }

  setup do
    Cache.reset()
  end

  describe "changeset/1" do
    @tag :tmp_dir
    test "when all files are new", %{tmp_dir: root} do
      File.touch!("#{root}/foo.fi")
      File.touch!("#{root}/bar.fi")

      assert ProjectCompiler.changeset(root) ==
               {[],
                [
                  "#{root}/bar.fi",
                  "#{root}/foo.fi"
                ], []}
    end

    @tag :tmp_dir
    test "when a file has changed", %{tmp_dir: root} do
      path = "#{root}/foo.fi"
      File.touch!(path)
      stat = File.stat!(path)
      Cache.update_stat(path, %{mtime: stat.mtime, size: stat.size})
      Cache.update_used_by(path, ["used_by1", "used_by2"])

      File.write!("#{root}/foo.fi", "file changed")

      assert ProjectCompiler.changeset(root) == {
               ["#{root}/foo.fi"],
               ["#{root}/foo.fi"],
               ["used_by1", "used_by2"]
             }
    end

    @tag :tmp_dir
    test "when a file is deleted", %{tmp_dir: root} do
      path = "#{root}/foo.fi"
      File.touch!(path)
      stat = File.stat!(path)
      Cache.update_stat(path, %{mtime: stat.mtime, size: stat.size})

      File.rm!("#{root}/foo.fi")

      assert ProjectCompiler.changeset(root) == {
               ["#{root}/foo.fi"],
               [],
               []
             }
    end

    @tag :tmp_dir
    test "when a file is deleted and it is used by other modules", %{tmp_dir: root} do
      path = "#{root}/foo.fi"
      File.touch!(path)
      stat = File.stat!(path)
      Cache.update_stat(path, %{mtime: stat.mtime, size: stat.size})
      Cache.update_used_by(path, ["used_by1", "used_by2"])

      File.rm!("#{root}/foo.fi")

      assert ProjectCompiler.changeset(root) == {
               ["#{root}/foo.fi"],
               [],
               ["used_by1", "used_by2"]
             }
    end
  end

  # describe "parse_all/1" do
  # @tag :tmp_dir
  # test "when files have parse errors", %{tmp_dir: tmp_dir} do
  # f1 = "#{tmp_dir}/foo.fi"
  # f2 = "#{tmp_dir}/bar.fi"

  # File.write!(f1, "hello world")
  # result = ProjectCompiler.parse_all([f1, f2])

  # Enum.each(result, fn {:error, %{message: message}} ->
  # assert message =~ "Cannot parse"
  # end)

  # refute Cache.get_ast(f1)
  # refute Cache.get_ast(f2)
  # end

  # @tag :tmp_dir
  # test "when files are ok", %{tmp_dir: tmp_dir} do
  # f1 = "#{tmp_dir}/foo.fi"
  # f2 = "#{tmp_dir}/bar.fi"

  # File.write!(f1, "fn\n foo : Int do\n 123 \n end")
  # File.write!(f2, "fn\n bar : Int do\n 123 \n end")
  # result = ProjectCompiler.parse_all([f1, f2])
  # assert result == [:ok, :ok]
  # refute Enum.empty?(Cache.get_ast(f1))
  # refute Enum.empty?(Cache.get_ast(f2))
  # end
  # end

  describe "compile/1" do
  end
end
