defmodule Alice.Hotspring do
  use HTTPoison.Base
  require Logger

  def process_url(url) do
    System.get_env("HOTSPRING_API") <> url
  end

  def process_response_body(body) do
    body |> Poison.decode!
  end

  def ctx(guild, channel, bot, shard, user) when is_binary(guild) and is_binary(channel) 
                                            and is_binary(bot) and is_integer(shard) 
                                            and is_binary(user) do
    %{
      "guild_id" => guild,
      "channel_id" => channel,
      "user_id" => user,
      "bot_id" => bot,
      "shard_id" => shard,
    }
  end

  def base(guild, channel, user) when is_binary(guild) and is_binary(channel) and is_map(user) do
    self = Alice.Shard.get_self()
    count = Alice.Shard.get_shard_count()
    shard = Alice.Util.guild_to_shard(String.to_integer(guild), count)
    ctx = ctx guild, channel, Integer.to_string(self["id"]), shard, Integer.to_string(user["id"])
    %{
      "ctx" => ctx
    }
  end

  def open_connection(user, vc, channel) when is_map(user) and is_binary(vc) and is_binary(channel) do
    guild = channel |> Alice.Cache.channel_to_guild_id
    voice_data = Alice.Shard.get_voice_connect_data guild, vc
    pkt = base(guild, channel, user)
          |> Map.put("session", voice_data["session"])
          |> Map.put("vsu", voice_data["vsu"])
    hotspring_res = post! "/connection/open", Poison.encode!(pkt), [{"Content-Type", "application/json"}]
    hotspring_res.body
  end

  def close_connection(user, channel) when is_map(user) and is_binary(channel) do
    guild = channel |> Alice.Cache.channel_to_guild_id
    pkt = base(guild, channel, user)
    hsres = post! "/connection/close", Poison.encode!(pkt), [{"Content-Type", "application/json"}]
    shard_res = Alice.Shard.voice_disconnect guild
    {hsres.body, shard_res.body}
  end

  def play(user, channel, url) when is_map(user) and is_binary(channel) and is_binary(url) do
    guild = channel |> Alice.Cache.channel_to_guild_id
    pkt = base(guild, channel, user)
          |> Map.put("url", url)
    res = post! "/connection/track/play", Poison.encode!(pkt), [{"Content-Type", "application/json"}]
    res.body
  end

  def pause(user, channel) when is_map(user) and is_binary(channel) do
    guild = channel |> Alice.Cache.channel_to_guild_id
    pkt = base(guild, channel, user)
    res = post! "/connection/track/pause", Poison.encode!(pkt), [{"Content-Type", "application/json"}]
    res.body
  end

  def queue(user, channel, url) when is_map(user) and is_binary(channel) and is_binary(url) do
    guild = channel |> Alice.Cache.channel_to_guild_id
    pkt = base(guild, channel, user)
          |> Map.put("url", url)
    res = post! "/connection/queue/add", Poison.encode!(pkt), [{"Content-Type", "application/json"}]
    res.body
  end

  def start_queue(user, channel) when is_map(user) and is_binary(channel) do
    guild = channel |> Alice.Cache.channel_to_guild_id
    pkt = base(guild, channel, user)
    res = post! "/connection/queue/start", Poison.encode!(pkt), [{"Content-Type", "application/json"}]
    res.body
  end

  def queue_length(user, channel) when is_map(user) and is_binary(channel) do
    guild = channel |> Alice.Cache.channel_to_guild_id
    pkt = base(guild, channel, user)
    res = post! "/connection/queue/length", Poison.encode!(pkt), [{"Content-Type", "application/json"}]
    res.body
  end

  def np(user, channel) when is_map(user) and is_binary(channel) do
    guild = channel |> Alice.Cache.channel_to_guild_id
    pkt = base(guild, channel, user)
    res = post! "/connection/track/current", Poison.encode!(pkt), [{"Content-Type", "application/json"}]
    res.body
  end

  def skip(user, channel, amount) when is_map(user) and is_binary(channel) and is_integer(amount) do
    guild = channel |> Alice.Cache.channel_to_guild_id
    pkt = base(guild, channel, user) 
          |> Map.put("skip", amount)
    res = post! "/connection/queue/skip", Poison.encode!(pkt), [{"Content-Type", "application/json"}]
  end
end