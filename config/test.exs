import Config

config :logger, level: :debug

config :ex_unit, capture_log: true

config :fika, Fika.Compiler.TypeChecker.FunctionDependencies, genserver_timeout: :infinity
