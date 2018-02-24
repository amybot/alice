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
    want to get an aggregate count across all guilds. 
  - Majority of stuff has been moved to using redis for my sanity. MongoDB was
    just maximeme :fire: for this :^( The rest of it is in Cassandra because
    Cassandra is bae <3
  """

  alias Lace.Redis
  require Logger

  # MongoDB collections
  @guild_cache "guild_cache"
  @emoji_cache "emoji_cache"

  # Cassandra stuff
  @guilds "amybot.guilds"

  # Redis keys
  @user_hash "user_cache"
  @voice_state_hash "voice_states"
  @channel_cache "channel_cache"
  @role_cache "role_cache"
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

  def get_member(guild_id, user_id) do
    guild_key = "guild:#{guild_id}:members"
    {:ok, user} = Redis.q ["HGET", guild_key, user_id]
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

  def get_guild(id) when is_integer(id) or is_binary(id) do
    # C Q L I N J E C T I O N
    {:ok, res} = Xandra.execute!(:cache, "SELECT * FROM #{@guilds} WHERE id = #{id}", [], pool: DBConnection.Poolboy) |> Enum.fetch(0)
    res
  end

  @doc """
  Convert a snowflake into a channel object
  """
  def get_channel(id) when is_integer(id) do
    {:ok, c} = Redis.q ["HGET", @channel_cache, id]
    case c do
      :undefined -> nil
      _ -> c |> Poison.decode!
    end
  end

  def get_channel(id) when is_binary(id) do
    id |> String.to_integer |> get_channel
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
    {:ok, res} = Xandra.execute!(:cache, "SELECT COUNT(*) FROM #{@guilds}", [], pool: DBConnection.Poolboy) |> Enum.fetch(0)
    res["count"]
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

  #################
  # Set up the DB #
  #################

  def prep_db do
    # Create the keyspace
    kres = Xandra.execute :cache, "CREATE KEYSPACE IF NOT EXISTS amybot WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor' : 1}", [], pool: DBConnection.Poolboy
    Logger.info "[DB] Keyspace: #{inspect kres, pretty: true}"
    # Get some tables up
    gres = Xandra.execute :cache, """
      CREATE TABLE IF NOT EXISTS #{@guilds} (
        id VARINT PRIMARY KEY, 
        afk_channel_id VARINT, 
        afk_timeout INT, 
        application_id VARINT, 
        default_message_notifications INT, 
        explicit_content_filter INT, 
        features LIST<TEXT>, 
        icon TEXT, 
        joined_at TEXT, 
        large BOOLEAN, 
        member_count INT, 
        mfa_level INT, 
        name TEXT, 
        owner_id VARINT, 
        region TEXT, 
        splash TEXT, 
        system_channel_id VARINT, 
        unavailable BOOLEAN, 
        verification_level INT
      );
      """, [], pool: DBConnection.Poolboy
    Logger.info "[DB] Guild table: #{inspect gres, pretty: true}"
    eres = Xandra.execute :cache, """
      CREATE TABLE IF NOT EXISTS amybot.emotes (
        id VARINT PRIMARY KEY, 
        guild_id VARINT,
        animated BOOLEAN,
        managed BOOLEAN,
        name TEXT,
        require_colons BOOLEAN,
        roles LIST<TEXT>
      );
      """, [], pool: DBConnection.Poolboy
    Logger.info "[DB] Emotes table: #{inspect eres, pretty: true}"
    # TODO: Need a counter table for members, because Cassandra is a meme like that  
  end

  ####################
  # Helper functions #
  ####################

  defp destring_field(map, field) do
    unless is_nil map[field] do
      map |> Map.put(field, String.to_integer(map[field]))
    else
      map
    end
  end

  defp update_guild(raw_guild) do
    {channels,     raw_guild} = Map.pop(raw_guild, "channels")
    {members,      raw_guild} = Map.pop(raw_guild, "members")
    {_presences,   raw_guild} = Map.pop(raw_guild, "presences")
    {voice_states, raw_guild} = Map.pop(raw_guild, "voice_states")
    {roles,        raw_guild} = Map.pop(raw_guild, "roles")
    {emojis,       raw_guild} = Map.pop(raw_guild, "emojis")
    Logger.info "[CACHE] Got new guild: #{inspect raw_guild["id"], pretty: true}"

    # Keep backwards compatibility x-x
    raw_guild = raw_guild
                |> Map.put("owner_id", String.to_integer(raw_guild["owner_id"]))
                |> Map.put("id", String.to_integer(raw_guild["id"]))
    raw_guild = raw_guild |> destring_field("system_channel_id") 
                          |> destring_field("afk_channel_id") 
                          |> destring_field("application_id")

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
    # Keep backwards compatibility x-x
    |> Enum.map(fn(x) -> %{x | "id" => String.to_integer(x["id"])} end)
    |> Enum.to_list
    |> handle_emotes_update

    # Dump it into db
    handle_guild_update raw_guild
    update_members_and_users raw_guild["id"], members

    handle_voice_states_initial voice_states

    # TODO: Do I even care about presences?
    #insert_many "presence_cache",    presences
  end

  defp generic_cassandra_upsert(table, data) when is_binary(table) and is_map(data) do
    # Alright.
    # This is absolutely fucking stupid.
    # NEVER do this for code that matters.
    # Okay?
    # Great. Don't judge me for this. It was the best way that
    # my 2am-brain could figure out to handle this.
    #
    # Now that the disclaimer is out of the way...
    # 
    # Basically, the problem is how inserting works. This isn't like
    # MongoDB, where we can just toss some JSON at it and pray. Instead,
    # we have to know the keys - and their names! - in advance. This is
    # an issue for the "naive" way of handling it.
    # 
    # So how do we solve this?
    #
    # Simple! Rather than guessing what keys will be present, we can 
    # just look at what's present on the object, then use those keys 
    # to build the query.
    # 
    # Discord *probably* isn't trying to CQL-inject us, so this is 
    # relatively safe, for certain values of "this is absolutely fucking
    # stupid and you should never do this in production code."
    #
    # Okay? Now don't judge me, I just wanted to get this done.
    #
    # I'm glad you understand.
    #
    # At least it's documented.
    # 
    # TODO: This might cause :fire: if ex. unexpected keys are present.
    # Could possibly solve this by ex. grabbing all possible columns from 
    # the table first, but that may have unexpected overhead(?)

    try do
      # Get all the keys
      keys = Map.keys data
      # Get the column string
      cols = Enum.join keys, ", "
      # Get the value string
      vals = keys |> Enum.map(fn(x) -> ":" <> x end) |> Enum.join(", ")
      # And now the insanity begins! Let's pray we're not about to get
      # CQL-injected!
      stmt = "INSERT INTO #{table} (#{cols}) VALUES (#{vals})"
      # Then we need to make our mapping object
      obj = keys |> Enum.reduce(%{}, fn(x, acc) -> 
                Map.put(acc, x, data[x])
              end)
      Logger.debug "[CACHE] [DB] Running query: #{stmt} with data #{inspect obj, pretty: true}"
      prep = Xandra.prepare! :cache, stmt, pool: DBConnection.Poolboy
      {:ok, res} = Xandra.execute :cache, prep, obj, pool: DBConnection.Poolboy
    rescue
      e ->
        Logger.warn "Cassandra :fire: - #{Exception.format(:error, e, System.stacktrace())}"
        Sentry.capture_exception e, [stacktrace: System.stacktrace()]
    end
  end

  defp handle_guild_update(guild) when is_map(guild) do
    generic_cassandra_upsert @guilds, guild
  end

  def handle_emotes_update(emotes) when is_list(emotes) do
    try do
      for emote <- emotes do
        generic_cassandra_upsert "amybot.emotes", emote
      end
    rescue
      e ->
        Logger.warn "Emotes :fire: - #{Exception.format(:error, e, System.stacktrace())}"
    end
  end

  defp update_channels(channels) do
    update_many @channel_cache, channels
  end

  defp update_roles(roles) do
    update_many @role_cache, roles
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
      Redis.t fn(worker) ->
          for state <- list do
            Redis.q worker, ["HSET", collection, state["id"], Poison.encode!(state)]
          end
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
    handle_guild_update raw_guild
  end

  def process_event(%{"t" => "GUILD_DELETE"} = event) do
    guild = event["d"]
    guild_key = "guild:#{guild["id"]}:members"
    if is_nil guild["unavailable"] do
      Xandra.execute! :cache, "DELETE FROM #{@guilds} WHERE id = #{guild["id"]}"
      Redis.q ["DEL", guild_key]
    end
  end

  def process_event(%{"t" => "CHANNEL_CREATE"} = event) do
    update_channels [event["d"]]
  end

  def process_event(%{"t" => "CHANNEL_UPDATE"} = event) do
    update_channels [event["d"]]
  end

  def process_event(%{"t" => "CHANNEL_DELETE"} = event) do
    Redis.q ["HDEL", @channel_cache, event["d"]["id"]]
  end

  def process_event(%{"t" => "GUILD_EMOJIS_UPDATE"} = event) do
    data = event["d"]
    guild = data["guild_id"]
    emojis = data["emojis"]
    emojis
    |> Enum.map(fn(x) -> add_id(guild, x) end)
    |> Enum.to_list
    |> handle_emotes_update
  end

  def process_event(%{"t" => "GUILD_MEMBER_ADD"} = event) do
    member = event["d"]
    update_members_and_users member["guild_id"], [member]
    # TODO: Cassandrafy
    #Mongo.update_one(:mongo_cache, @guild_cache, %{"id": member["guild_id"]}, 
    #  %{"$inc": %{"member_count": 1}}, [pool: DBConnection.Poolboy, upsert: true])
  end

  def process_event(%{"t" => "GUILD_MEMBER_REMOVE"} = event) do
    guild_id = event["d"]["guild_id"]
    user = event["d"]["user"]
    Redis.q ["HDEL", "guild:#{guild_id}:members", user["id"]]
    # TODO: Cassandrafy
    #Mongo.update_one(:mongo_cache, @guild_cache, %{"id": guild_id}, 
    #  %{"$inc": %{"member_count": -1}}, [pool: DBConnection.Poolboy, upsert: true])
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
    Redis.q ["HDEL", @role_cache, event["d"]["role_id"]]
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
