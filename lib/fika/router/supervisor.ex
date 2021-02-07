defmodule Fika.Router.Supervisor do
  use Supervisor

  def start do
    Supervisor.start_child(Fika.Supervisor, __MODULE__)
  end

  def start_link(_) do
    unless Application.get_env(:fika, :disable_web_server) do
      Supervisor.start_link(__MODULE__, [], name: __MODULE__)
    else
      :ignore
    end
  end

  @impl true
  def init(_) do
    unless File.exists?("router.fi") do
      IO.puts("router.fi not found. Creating an example router in file router.fi")
      Fika.Router.create_example_router()
    end

    children = [
      {Fika.Router.Store, []},
      {Plug.Cowboy, scheme: :http, plug: Fika.Router, options: [port: 9090, ip: {127, 0, 0, 1}]}
    ]

    Supervisor.init(children, strategy: :one_for_one, name: __MODULE__)
  end
end
