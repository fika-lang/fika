import Config

config :fika,
  start_cli: true,
  router_path: "router.fi",
  dev_token: System.get_env("FIKA_DEV_TOKEN"),
  remote_endpoint: System.get_env("FIKA_REMOTE_ENDPOINT")
