defmodule Alice.Cache do
  @moduledoc """
  ## Some things to note

  - As of writing, there's no efficient user-reference-counting that I've
    figured out for allowing pruning useres from the cache. At best they all 
    turn into O(3N) or so, and that's an issue because sometimes N = 50000. 
    Can't just use a Redis ZSET for reference-counting, because references will
    duplicate every time a shard (re)starts. 
  - This was originally a separate worker BEAM instance, but has been moved 
    into this application mainly for efficiency - this way there's no need for
    an extra round-trip to hit up redis for events, we can just keep it all 
    in-process and lose nothing. 
  """

  alias Lace.Redis
  require Logger

  @guild_cache "guild_cache"
  @channel_cache "channel_cache"
  @role_cache "role_cache"
  #@emoji_cache "emoji_cache"
  @emoji_schema "amybot_emote_cache"

  @user_hash "users"
  @voice_state_hash "voice_states"

  ################
  # External API #
  ################

  ##########################################################
  # LIST OF THINGS TO DO                                   #
  # - In-process fast lookup table for channel -> guild id #
  # - Real emote handling                                  #
  # - Voice states                                         #
  ##########################################################

  def get_user(id) do
    {:ok, user} = Redis.q ["HGET", @user_hash, id]
    case user do
      :undefined -> nil
      _ -> user |> Poison.decode!
    end
  end

  @doc """
  Convert a snowflake into a channel object
  """
  def get_channel(id) do
    Mongo.find_one :mongo, @channel_cache, %{"id": id}, pool: DBConnection.Poolboy
  end

  def is_nsfw(id) do
    get_channel(id)["nsfw"] || false
  end

  def channel_to_guild_id(channel) when is_integer(channel) do
    get_channel(channel)["guild_id"]
  end

  def channel_to_guild_id(channel) when is_map(channel) do
    get_channel(channel["id"])["guild_id"]
  end

  def count_guilds do
    Mongo.count :mongo, @guild_cache, %{}, pool: DBConnection.Poolboy
  end

  def get_voice_state(id) do
    {:ok, state} = Redis.q ["HGET", @voice_state_hash, id]
    case state do
      :undefined -> nil
      _ -> state |> Poison.decode!
    end
  end

  ###############################################################################
  # Internal functions start below this line. You're probably looking for the   #
  # "External API" functions above. This is likely not what you're looking for, #
  # unless you're chasing down a bug in something.                              #
  ###############################################################################

  #####################################################################################################################
  #####################################################################################################################
  #####################################################################################################################

  ####################
  # Helper functions #
  ####################

  defp update_guild(raw_guild) do
    {channels,     raw_guild} = Map.pop(raw_guild, "channels")
    {members,      raw_guild} = Map.pop(raw_guild, "members")
    {_presences,   raw_guild} = Map.pop(raw_guild, "presences")
    {voice_states, raw_guild} = Map.pop(raw_guild, "voice_states")
    {roles,        raw_guild} = Map.pop(raw_guild, "roles")
    {emojis,       raw_guild} = Map.pop(raw_guild, "emojis")
    # Do some cleaning
    channels
    |> Enum.map(fn(x) -> add_id(raw_guild, x) end)
    |> Enum.to_list
    |> update_channels

    roles
    |> Enum.map(fn(x) -> add_id(raw_guild, x) end)
    |> Enum.to_list
    |> update_roles

    emojis
    |> Enum.map(fn(x) -> add_id(raw_guild, x) end)
    |> Enum.to_list
    |> update_emojis

    # Dump it into db
    Mongo.update_one(:mongo, @guild_cache, %{"id": raw_guild["id"]}, 
      %{"$set": raw_guild}, [pool: DBConnection.Poolboy, upsert: true])
    update_members_and_users raw_guild["id"], members

    handle_voice_states voice_states

    # TODO: Do I even care about presences?
    #insert_many "presence_cache",    presences
  end

  defp update_channels(channels) do
    update_many @channel_cache, channels
  end

  defp update_roles(roles) do
    update_many @role_cache, roles
  end

  defp update_emojis(emojis) do
    emote_upd = emojis
                |> Enum.map(fn(emote) -> 
                    emote
                    |> Map.delete("roles")
                    |> Map.delete("user")
                  end)
                |> Enum.to_list
    #update_many @emoji_cache, emojis
    Logger.info "Updating emote cache..."
    try do
      Alice.WriteRepo.insert_all @emoji_schema, emote_upd
    rescue
      e -> Logger.warn "Update :fire: - #{inspect e}"
    end
    Logger.info "Done!"
  end

  defp handle_voice_states(states) do
    states
    |> Enum.chunk_every(100)
    |> Enum.each(fn(chunk) -> 
          Redis.t fn(worker) ->
              for state <- chunk do
                Redis.q worker, ["HSET", @voice_state_hash, state["user_id"], Poison.encode!(state)]
              end
            end
        end)
  end

  defp update_many(collection, list) do
    unless length(list) == 0 do
      # So this is really bad, but apparently making a nice update_many filter 
      # will be god-awful :(
      for snowflake <- list do
        Mongo.update_one :mongo, collection, %{"id": snowflake["id"]}, %{"$set": snowflake}, 
          [pool: DBConnection.Poolboy, upsert: true]
      end
    end
  end

  defp update_members_and_users(guild_id, list) do
    list
    # Gives us a list of [{user object, member object}]
    |> Enum.map(fn(m) -> member_to_user(guild_id, m) end)
    # Don't usually need to do any complex queries over users, 
    # so store them in redis
    # Chunks every 1k members so as to not overwhelm redis with a single
    # giant transaction, since other chunks will be trying to write too
    |> Enum.chunk_every(1000)
    |> Enum.each(fn(chunk) -> handle_user_chunk(guild_id, chunk) end)
  end

  @doc """
  Note that this method stores member objects in a *hash* that 
  corresponds to the guild. This is so that we can trivially do do a 
  fast-delete of all a guild's members, while still not losing the ability to
  query this info based on guild id
  """
  defp handle_user_chunk(guild_id, chunk) do
    guild_key = "guild:#{guild_id}:members"
    Redis.t fn(worker) -> 
        for {user, member} <- chunk do
          Redis.q worker, ["HSET", @user_hash, user["id"], Poison.encode!(user)]
          #Redis.q worker, ["ZINCRBY", @user_zset, 1, user["id"]]
          Redis.q worker, ["HSET", guild_key, user["id"], Poison.encode!(member)]
        end
      end
  end

  defp member_to_user(guild_id, member) do
    {user, member} = Map.pop member, "user"
    member = member |> Map.put("guild", guild_id)
                    |> Map.put("user", user["id"])
    {user, member}
  end

  @doc """
  Ensure that entities always have a guild_id attached
  """
  defp add_id(guild, entity) when is_map(guild) do
    entity |> Map.put("guild_id", guild["id"])
  end

  defp add_id(guild, entity) when is_integer(guild) do
    entity |> Map.put("guild_id", guild)
  end

  ##############################
  # Event-processing functions #
  ##############################

  def process_event(%{"t" => "GUILD_CREATE"} = event) do
    update_guild event["d"]
  end

  def process_event(%{"t" => "GUILD_UPDATE"} = event) do
    raw_guild = event["d"]
    # GUILD_UPDATE doesn't contain anywhere NEAR as much as GUILD_CREATE does,
    # so we only update the guild cache
    Mongo.update_one(:mongo, @guild_cache, %{"id": raw_guild["id"]}, 
      %{"$set": raw_guild}, [pool: DBConnection.Poolboy, upsert: true])
  end

  def process_event(%{"t" => "GUILD_DELETE"} = event) do
    guild = event["d"]
    guild_key = "guild:#{guild["id"]}:members"
    if is_nil guild["unavailable"] do
      Mongo.delete_one(:mongo, @guild_cache, %{"id": guild["id"]}, [pool: DBConnection.Poolboy])
      #{:ok, ids} = Redis.q ["HKEYS", guild_key]
      Redis.q ["DEL", guild_key]
      #ids
      #|> Enum.chunk_every(1000)
      #|> Enum.each(fn(chunk) -> 
      #    Redis.t fn(worker) -> 
      #        for id <- chunk do
      #          Redis.q worker, ["ZINCRBY", @user_zset, -1, id]
      #        end
      #      end
      #  end)
      ## Garbage-collect when an id runs out of references
      #{:ok, prunable_users} = Redis.q ["ZRANGEBYSCORE", @user_zset, "-inf", 0]
      #Redis.q ["ZREMRANGEBYSCORE", @user_zset, "-inf", 0]
      #prunable_users
      #|> Enum.chunk_every(1000)
      #|> Enum.each(fn(chunk) -> 
      #    Redis.t fn(worker) -> 
      #        for id <- chunk do
      #          Redis.q worker, ["HDEL", @user_hash, id]
      #        end
      #      end
      #  end)
    end
  end

  def process_event(%{"t" => "CHANNEL_CREATE"} = event) do
    update_channels [event["d"]]
  end

  def process_event(%{"t" => "CHANNEL_UPDATE"} = event) do
    update_channels [event["d"]]
  end

  def process_event(%{"t" => "CHANNEL_DELETE"} = event) do
    Mongo.delete_one(:mongo, @channel_cache, %{"id": event["d"]["id"]}, [pool: DBConnection.Poolboy])
  end

  def process_event(%{"t" => "GUILD_EMOJIS_UPDATE"} = event) do
    data = event["d"]
    guild = data["guild_id"]
    emojis = data["emojis"]
    Alice.WriteRepo.prune_emotes guild
    emojis
    |> Enum.map(fn(x) -> add_id(guild, x) end)
    |> Enum.to_list
    |> update_emojis
  end

  def process_event(%{"t" => "GUILD_MEMBER_ADD"} = event) do
    member = event["d"]
    update_members_and_users member["guild_id"], [member]
    Mongo.update_one(:mongo, @guild_cache, %{"id": member["guild_id"]}, 
      %{"$inc": %{"member_count": 1}}, [pool: DBConnection.Poolboy, upsert: true])
  end

  def process_event(%{"t" => "GUILD_MEMBER_REMOVE"} = event) do
    guild_id = event["d"]["guild_id"]
    user = event["d"]["user"]
    Redis.q ["HDEL", "guild:#{guild_id}:members", user["id"]]
    #Redis.q ["ZINCRBY", @user_zset, -1, user["id"]]
    Mongo.update_one(:mongo, @guild_cache, %{"id": guild_id}, 
      %{"$inc": %{"member_count": -1}}, [pool: DBConnection.Poolboy, upsert: true])
  end

  def process_event(%{"t" => "GUILD_MEMBER_UPDATE"} = event) do
    member = event["d"]
    update_members_and_users member["guild_id"], [member]
  end

  def process_event(%{"t" => "GUILD_MEMBERS_CHUNK"} = event) do
    chunk = event["d"]
    update_members_and_users chunk["guild_id"], chunk["members"]
  end

  def process_event(%{"t" => "GUILD_ROLE_CREATE"} = event) do
    update_roles [event["d"]]
  end

  def process_event(%{"t" => "GUILD_ROLE_UPDATE"} = event) do
    update_roles [event["d"]]
  end

  def process_event(%{"t" => "GUILD_ROLE_DELETE"} = event) do
    Mongo.delete_one(:mongo, @role_cache, %{"id": event["d"]["role_id"]}, [pool: DBConnection.Poolboy])
  end

  def process_event(%{"t" => "PRESENCE_UPDATE"} = _event) do
    # Make this not NOOP?
  end

  def process_event(%{"t" => "USER_UPDATE"} = event) do
    user = event["d"]
    {:ok, cached_user} = Redis.q ["HGET", @user_hash, user["id"]]
    unless cached_user == :undefined do
      Redis.q ["HSET", @user_hash, user["id"], Map.merge(cached_user, user)]
    else
      Logger.warn "Got USER_UPDATE for unknown user: #{user["id"]}!"
    end
  end

  def process_event(%{"t" => "VOICE_STATE_UPDATE"} = event) do
    handle_voice_states [event["d"]]
  end
  
  ##################
  # NOOP catch-all #
  ##################

  def process_event(event) do
    Logger.debug "Got unknown event: #{inspect event}"
  end
end
