defmodule Fika.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, port: port) do
    children = [
      {Fika.RouteStore, []},
      {Plug.Cowboy, scheme: :http, plug: Fika.Router, options: [port: port, ip: {127, 0, 0, 1}]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fika.Supervisor]
    sup = Supervisor.start_link(children, opts)

    IO.puts("Web server is running on http://localhost:#{port}\nPress Ctrl+C to exit")
    sup
  end
end
