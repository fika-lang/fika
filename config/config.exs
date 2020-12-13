import Config

unless System.get_env("BAKEWARE_ARGC") do
  System.put_env("BAKEWARE_ARGC", "0")
end

config :logger, level: :debug, metadata: :all
