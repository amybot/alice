defmodule Alice.Util do
  @moduledoc """
  Utilities for commands and stuff.
  """

  import Emily.Embed
  require Logger

  import Bitwise

  def guild_to_shard(guild_id, shard_count) do
    (guild_id >>> 22) |> rem(shard_count)
  end

  @doc """
  Returns the current time in milliseconds
  """
  def now_ms do
    :os.system_time :millisecond
  end

  @doc """
  Returns the current time in seconds
  """
  def now_s do
    :os.system_time :second
  end

  def avatar(user) do
    "https://cdn.discordapp.com/avatars/#{user["id"]}/#{user["avatar"]}.png"
  end

  def track_event_embed(track_event) do
    user = track_event["ctx"]["userId"] |> Alice.Cache.get_user
    uname = unless is_nil user do
              user["username"]
            else
              "an unknown user"
            end
    pfp = unless is_nil user do
            avatar(user)
          else
            # TODO: This isn't right but idk what else to do rn
            "https://discordapp.com/assets/2c21aeda16de354ba5334551a883b481.png"
          end
    embed()
    |> footer("Requested by #{uname}", pfp)
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
