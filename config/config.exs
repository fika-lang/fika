import Config

unless System.get_env("BAKEWARE_ARGC") do
  System.put_env("BAKEWARE_ARGC", "0")
end

# Defines that we should not print the usage string and halt
config :fika, Fika.Cli, print_usage: false
