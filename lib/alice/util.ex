defmodule Alice.Util do
  @moduledoc """
  Utilities for commands
  """

  import Emily.Embed
  require Logger

  def avatar(user) do
    "https://cdn.discordapp.com/avatars/#{user["id"]}/#{user["avatar"]}.png"
  end

  def ctx_embed(ctx) do
    embed()
    |> footer("Requested by #{ctx["author"]["username"]}", avatar(ctx["author"]))
  end

  def error(ctx, msg) when is_map(ctx) and is_binary(msg) do
    ctx
    |> ctx_embed
    |> title("Error!")
    |> color(0xFF0000)
    |> desc(msg)
  end
end
