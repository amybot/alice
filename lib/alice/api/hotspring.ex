defmodule Alice.Hotspring do
  @moduledoc """
  TODO: fill out docs

  TODO: Make this not require the outside to pass in info
  """

  use HTTPoison.Base

  def process_url(url) do
    System.get_env("HOTSPRING_API") <> url
  end

  def process_response_body(body) do
    body |> Poison.decode!
  end

  def open_connection(guild, channel) when is_integer(guild) and is_integer(channel) do
    open_connection(Integer.to_string(guild), Integer.to_string(channel))
  end

  @doc """
  Will time out in 60 seconds. This is intentional, because that should be MORE
  than enough time for the shards to recover enough gateway events to be able
  to do stuff
  """
  def open_connection(guild, channel) when is_binary(guild) and is_binary(channel) do
    voice_data = Alice.Shard.get_voice_connect_data guild, channel
    hotspring_res = post! "/connection/open", Poison.encode!(voice_data), [{"Content-Type", "application/json"}]
    hotspring_res.body
  end

  def close_connection(bot, guild) when is_integer(bot) and is_integer(guild) do
    close_connection(Integer.to_string(bot), Integer.to_string(guild))
  end

  def close_connection(bot, guild) when is_binary(bot) and is_binary(guild) do
    # compute shard id of the guild
    count = Alice.Shard.get_shard_count()["shard_count"]
    shard = Alice.Util.guild_to_shard(String.to_integer(guild), count)
    hsres = post! "/connection/close", Poison.encode!(%{
                    "bot_id" => bot, 
                    "shard_id" => shard, 
                    "guild_id" => guild
                  }), [{"Content-Type", "application/json"}]
    shard_res = Alice.Shard.voice_disconnect guild
    {hsres.body, shard_res.body}
  end

  def play(url, txt_channel) do
    channel_id = if is_binary(txt_channel) do
              txt_channel |> String.to_integer
            else
              txt_channel
            end
    guild = Alice.Cache.channel_to_guild_id(channel_id) |> Integer.to_string
    bot_id = Alice.Shard.get_self_id()
    count = Alice.Shard.get_shard_count()["shard_count"]
    shard = Alice.Util.guild_to_shard(String.to_integer(guild), count)
    data = %{
      "url" => url,
      "bot_id" => bot_id,
      "shard_id" => shard,
      "guild_id" => guild,
      "channel_id" => Integer.to_string(channel_id),
    }
    res = post! "/connection/track/play", Poison.encode!(data), [{"Content-Type", "application/json"}]
    res.body
  end
end