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
    an extra round-trip to hit up redis for data, we can just keep it all 
    in-process and lose nothing. 
  - Data is stored in a couple different places, for a variety of reasons. 
    These mostly boil down to speed vs. querying-ability. For example, I 
    generally just want to get user data quickly, whereas with guilds I may 
    want to get an aggregate count across all guilds. Emotes specifically are 
    stored in PostgreSQL because it's the easiest way to do some of the ugly
    queries that are necessary (ex `row_number() ... PARTITION BY`-type
    queries). 
  """

  alias Lace.Redis
  require Logger

  # MongoDB collections
  @guild_cache "guild_cache"
  @channel_cache "channel_cache"
  @role_cache "role_cache"
  @emoji_cache "emoji_cache"

  # Redis keys
  @user_hash "users"
  @voice_state_hash "voice_states"
  # Note that our client's voice state is "special," because a bot can be in 
  # many voice channels. We don't care about bots, because we only want users
  # listening anyway. 
  @self_voice_hash "self_voice_states"
  # We maintain a global set of voice states, as well as a per-channel set with
  # this suffix. This is so that when a user leaves a channel, we can use their
  # voice states to determine if we can pause/stop the player. 
  @channel_voice_states ":voice-states"

  ################
  # External API #
  ################

  # So something to pay attention to here:
  #
  # The external API is honestly kind of a trainwreck, for a variety of 
  # reasons. Some of these reasons are due to bad planning, others are due to 
  # the fact that different things require different data formats; ex. this 
  # lib. supports using integers for all snowflake operations, but Hotspring 
  # (JDA-A based) requires strings for snowflakes. This external API is a mess
  # beacuse it tries to cover ALL these use-cases.
  #
  # You've been warned. 

  def get_user(id) do
    {:ok, user} = Redis.q ["HGET", @user_hash, id]
    case user do
      :undefined -> nil
      _ -> user |> Poison.decode!
    end
  end

  def get_voice_channel(snowflake) do
    state = get_voice_state snowflake
    case state do
      nil -> nil
      _ -> state["channel_id"]
    end
  end

  @doc """
  Convert a snowflake into a channel object
  """
  def get_channel(id) when is_integer(id) do
    Mongo.find_one :mongo_cache, @channel_cache, %{"id": id}, pool: DBConnection.Poolboy
  end

  # TODO: WTF IS THIS FUNCTION NAME
  def get_channel(id) when is_binary(id) do
    id |> String.to_integer |> get_channel |> Access.get("id")
  end

  def get_channel_name(id) when is_integer(id) do
    id |> get_channel |> Access.get("name")
  end

  def get_channel_name(id) when is_binary(id) do
    id |> String.to_integer |> get_channel_name
  end

  def is_nsfw(id) do
    get_channel(id)["nsfw"] || false
  end

  def channel_to_guild_id(channel) when is_integer(channel) do
    get_channel(channel)["guild_id"]
  end

  def channel_to_guild_id(channel) when is_binary(channel) do
    channel |> String.to_integer |> channel_to_guild_id |> Integer.to_string
  end

  def channel_to_guild_id(channel) when is_map(channel) do
    get_channel(channel["id"])["guild_id"]
  end

  def count_guilds do
    Mongo.count :mongo_cache, @guild_cache, %{}, pool: DBConnection.Poolboy
  end

  @doc """
  DO NOT USE THIS FOR SELF VOICE STATE!!!!!!!!!!!!!!!!!
  """
  def get_voice_state(id) do
    {:ok, state} = Redis.q ["HGET", @voice_state_hash, id]
    case state do
      :undefined -> nil
      _ -> state |> Poison.decode!
    end
  end

  def get_self_voice_state_guild(guild) do
    {:ok, state} = Redis.q ["HGET", @self_voice_hash, guild]
    case state do
      :undefined -> nil
      _ -> state |> Poison.decode!
    end
  end

  def get_self_voice_state_channel(channel) do
    guild = channel_to_guild_id channel
    {:ok, state} = Redis.q ["HGET", @self_voice_hash, guild]
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
    Mongo.update_one(:mongo_cache, @guild_cache, %{"id": raw_guild["id"]}, 
      %{"$set": raw_guild}, [pool: DBConnection.Poolboy, upsert: true])
    update_members_and_users raw_guild["id"], members

    handle_voice_states_initial voice_states

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
    update_many @emoji_cache, emojis
  end

  defp handle_self_voice_state(state) do
    unless is_nil state["channel_id"] do
      # Channel, update guild
      guild = unless is_nil state["guild_id"] do
                state["guild_id"]
              else
                channel_to_guild_id state["channel_id"]
              end
      Redis.q ["HSET", @self_voice_hash, guild, Poison.encode!(state)]              
    else
      # No channel, remove guild
      guild = state["guild_id"]
      Redis.q ["HDEL", @self_voice_hash, guild]
    end
  end

  defp handle_voice_state(state) do
    try do
      {:ok, unparsed} = Redis.q ["HGET", @voice_state_hash, state["user_id"]]
      unless unparsed == :undefined do
        old_state = unparsed |> Poison.decode!
        unless is_nil old_state["channel_id"]  do
          # If the old state isn't nil, remove it
          old_channel = old_state["channel_id"]
          Redis.q ["HDEL", "#{inspect old_channel}#{@channel_voice_states}", state["user_id"]]
        end
      end
      # Update the main voice state
      Redis.q ["HSET", @voice_state_hash, state["user_id"], Poison.encode!(state)]
      # Update new channel state if needed
      unless is_nil state["channel_id"] do
        Redis.q ["HSET", "#{inspect state["channel_id"]}#{@channel_voice_states}", state["user_id"], true]
      end
    rescue
      e -> 
        Logger.warn "#{inspect e, pretty: true} - #{inspect System.stacktrace(), pretty: true}"
    end
  end

  defp handle_voice_states_initial(states) do
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
        Mongo.update_one :mongo_cache, collection, %{"id": snowflake["id"]}, %{"$set": snowflake}, 
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

  # Ensure that entities always have a guild_id attached
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
    Mongo.update_one(:mongo_cache, @guild_cache, %{"id": raw_guild["id"]}, 
      %{"$set": raw_guild}, [pool: DBConnection.Poolboy, upsert: true])
  end

  def process_event(%{"t" => "GUILD_DELETE"} = event) do
    guild = event["d"]
    guild_key = "guild:#{guild["id"]}:members"
    if is_nil guild["unavailable"] do
      Mongo.delete_one(:mongo_cache, @guild_cache, %{"id": guild["id"]}, [pool: DBConnection.Poolboy])
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
    Mongo.delete_one(:mongo_cache, @channel_cache, %{"id": event["d"]["id"]}, [pool: DBConnection.Poolboy])
  end

  def process_event(%{"t" => "GUILD_EMOJIS_UPDATE"} = event) do
    data = event["d"]
    guild = data["guild_id"]
    emojis = data["emojis"]
    Mongo.delete_many(:mongo_cache, @emoji_cache, %{"guild_id": guild})
    emojis
    |> Enum.map(fn(x) -> add_id(guild, x) end)
    |> Enum.to_list
    |> update_emojis
  end

  def process_event(%{"t" => "GUILD_MEMBER_ADD"} = event) do
    member = event["d"]
    update_members_and_users member["guild_id"], [member]
    Mongo.update_one(:mongo_cache, @guild_cache, %{"id": member["guild_id"]}, 
      %{"$inc": %{"member_count": 1}}, [pool: DBConnection.Poolboy, upsert: true])
  end

  def process_event(%{"t" => "GUILD_MEMBER_REMOVE"} = event) do
    guild_id = event["d"]["guild_id"]
    user = event["d"]["user"]
    Redis.q ["HDEL", "guild:#{guild_id}:members", user["id"]]
    #Redis.q ["ZINCRBY", @user_zset, -1, user["id"]]
    Mongo.update_one(:mongo_cache, @guild_cache, %{"id": guild_id}, 
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
    Mongo.delete_one(:mongo_cache, @role_cache, %{"id": event["d"]["role_id"]}, [pool: DBConnection.Poolboy])
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
    self_id = Alice.Shard.get_self()["id"]
    user_id = event["d"]["user_id"]
    if user_id == self_id do
      handle_self_voice_state event["d"]
    else
      handle_voice_state event["d"]
    end
  end
  
  ##################
  # NOOP catch-all #
  ##################

  def process_event(event) do
    Logger.debug "Got unknown event: #{inspect event}"
  end
end
