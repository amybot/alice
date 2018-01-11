defmodule Alice.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/", do: send_resp(conn, 200, "yes")
  match _, do: send_resp(conn, 404, "no")
end