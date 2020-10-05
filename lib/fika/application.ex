defmodule Fika.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, port: port) do
    children =
      if is_integer(port) do
        c = [
          {Fika.RouteStore, []},
          {Plug.Cowboy,
           scheme: :http, plug: Fika.Router, options: [port: port, ip: {127, 0, 0, 1}]}
        ]

        IO.puts("Web server is running on http://localhost:#{port}\nPress Ctrl+C to exit")

        c
      else
        []
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fika.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
