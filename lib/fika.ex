defmodule Fika do
  def start(path \\ nil) do
    if path do
      File.cd!(path)
    end

    if File.exists?("router.fi") do
      start_route_store()
      start_webserver()
      :ok
    else
      IO.puts("Cannot start webserver: file router.fi not found.")
      :error
    end
  end

  def start_route_store do
    {:ok, _pid} = Supervisor.start_child(Fika.Supervisor, Fika.RouteStore)
  end

  def start_webserver(port \\ 6060) do
    {:ok, _pid} =
      Supervisor.start_child(
        Fika.Supervisor,
        {Plug.Cowboy, scheme: :http, plug: Fika.Router, options: [port: port, ip: {127, 0, 0, 1}]}
      )

    IO.puts("Web server is running on http://localhost:#{port}\nPress Ctrl+C to exit")
  end
end
