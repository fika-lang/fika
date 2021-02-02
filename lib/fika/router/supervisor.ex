defmodule Fika.Router.Supervisor do
  use Supervisor

  def start do
    Supervisor.start_child(Fika.Supervisor, __MODULE__)
  end

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [
      {Fika.Router.Store, []},
      {Plug.Cowboy, scheme: :http, plug: Fika.Router, options: [port: 9090, ip: {127, 0, 0, 1}]}
    ]

    Supervisor.init(children, strategy: :one_for_one, name: __MODULE__)
  end
end
