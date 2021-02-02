defmodule Fika.Router.Store do
  use Agent

  require Logger

  def start_link(_) do
    Agent.start_link(fn -> init_routes() end, name: __MODULE__)
  end

  def get_route(method, path) do
    Agent.get(__MODULE__, fn routes ->
      routes["#{method}:#{path}"]
    end)
  end

  def init_routes do
    Logger.debug("Initializing Router.Store")
    router = Application.get_env(:fika, :router_path)

    if File.exists?(router) do
      load_routes(router)
    else
      Logger.debug("Not loading routes. Router not found: #{router}")
    end
  end

  def load_routes(router) do
    module = String.replace_suffix(router, ".fi", "")
    Fika.Code.load_module(module)
    erl_module_name = Fika.Compiler.ErlTranslate.erl_module_name(module)

    if function_exported?(erl_module_name, :routes, 0) do
      routes = erl_module_name.routes()

      Enum.into(routes, %{}, fn %{method: method, path: path, handler: function} ->
        {"#{method}:#{path}", function}
      end)
    else
      Logger.error("Router has no function routes/0")
      %{}
    end
  end

  def reload_routes(router) do
    Logger.debug("Reloading routes")

    router
    |> load_routes()
    |> put_routes()
  end

  def put_routes(routes) do
    Agent.update(__MODULE__, fn _routes ->
      routes
    end)
  end

  def list_routes do
    Agent.get(__MODULE__, fn routes -> routes end)
  end
end
