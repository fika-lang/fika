import Config

unless System.get_env("BAKEWARE_ARGC") do
  System.put_env("BAKEWARE_ARGC", "0")
end

config :fika, :router_path, "examples/router.fi"
