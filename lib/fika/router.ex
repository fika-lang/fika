defmodule Fika.Router do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    {status, resp} = get_resp(conn.method, conn.request_path)
    send_resp(conn, status, resp)
  end

  def create_example_router do
    content = """
    fn routes : List({method: String, path: String, handler: Fn(->String)}) do
      [
        {method: "GET", path: "/", handler: &greet}
      ]
    end

    fn greet : String do
      "Hello world"
    end
    """

    File.write("router.fi", content)
  end

  defp get_resp(method, path) do
    case Fika.Router.Store.get_route(method, path) do
      nil ->
        {404, "Not found"}

      function ->
        body = function.()
        {200, body}
    end
  end
end
