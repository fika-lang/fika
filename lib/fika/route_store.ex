defmodule Fika.RouteStore do
  use Agent

  require Logger

  def start_link(_) do
    Agent.start_link(fn -> load_routes() end, name: __MODULE__)
  end

  def get_route(method, path) do
    Agent.get(__MODULE__, fn routes ->
      routes["#{method}:#{path}"]
    end)
  end

  def load_routes do
    Fika.Code.load_module("router")

    if function_exported?(:router, :routes, 0) do
      routes = :router.routes()

      Enum.into(routes, %{}, fn %{method: method, path: path, handler: function} ->
        {"#{method}:#{path}", function}
      end)
    else
      Logger.error("Router has no function routes/0")
      %{}
    end
  end

  def put_routes(routes) do
    Agent.update(__MODULE__, fn _routes ->
      routes
    end)
  end

  def reload_routes do
    load_routes()
    |> put_routes()
  end

  def list_routes do
    Agent.get(__MODULE__, fn routes -> routes end)
  end
end
