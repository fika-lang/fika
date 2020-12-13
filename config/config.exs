import Config

unless System.get_env("BAKEWARE_ARGC") do
  System.put_env("BAKEWARE_ARGC", "0")
end

if Mix.env() == :test do
  import_config "test.exs"
end
