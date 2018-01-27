defmodule Alice.Database do
  @users "users"
  @guilds "guilds"

  @update_args [pool: DBConnection.Poolboy, upsert: true]

  ##########################
  # Guild-level operations #
  ##########################

  def get_guild(guild) do
    guild = handle_in guild
    Mongo.find_one :mongo, @guilds, %{"id": guild}, pool: DBConnection.Poolboy
  end

  def get_custom_prefix(guild) do
    guild = handle_in guild
    get_guild(guild)["custom_prefix"]
  end

  def set_custom_prefix(guild, prefix) when is_binary(prefix) do
    guild = handle_in guild
    Mongo.update_one :mongo, @guilds, %{"id": guild}, %{"$set": %{"custom_prefix": prefix}}, @update_args
  end

  def get_language(guild) do
    guild = handle_in guild
    lang = get_guild(guild)["lang"]
    if is_nil lang do
      Mongo.update_one :mongo, @guilds, %{"id": guild}, %{"$set": %{"lang": "en"}}, @update_args
      "en"
    else
      lang
    end
  end

  def set_language(guild, lang) when is_binary(lang) do
    guild = handle_in guild
    if lang in Alice.I18n.get_langs() do
      Mongo.update_one :mongo, @guilds, %{"id": guild}, %{"$set": %{"lang": lang}}, @update_args
      {:ok, nil}
    else
      {:error, :invalid_lang}
    end
  end

  #########################
  # User-level operations #
  #########################

  def get_user(user) do
    user = handle_in user
    Mongo.find_one :mongo, @users, %{"id": user}, pool: DBConnection.Poolboy
  end

  #######################
  # Currency operations #
  #######################

  def increment_balance(user, amount) when is_integer(amount) do
    user = handle_in user
    Mongo.update_one :mongo, @users, %{"id": user}, %{"$inc": %{"balance": amount}}, @update_args
  end

  def set_balance(user, amount) when is_integer(amount) do
    user = handle_in user
    Mongo.update_one :mongo, @users, %{"id": user}, %{"$set": %{"balance": amount}}, @update_args
  end

  def balance(user) do
    user = handle_in user
    balance = get_user(user)["balance"]
    if is_nil balance do
      set_balance user, 0
      0
    else
      balance
    end
  end

  def balance_top do
    Mongo.aggregate :mongo, @users, [
        %{"$sort": %{"balance": -1}},
        %{"$limit": 10}
      ], pool: DBConnection.Poolboy
  end

  #####################
  # Levels operations #
  #####################

  # Global levels #

  def get_xp(user) do
    user = handle_in user
    xp = get_user(user)["xp"]
    if is_nil xp do
      set_xp user, 0
      0
    else
      xp
    end
  end

  def increment_xp(user, amount) when is_integer(amount) do
    user = handle_in user
    Mongo.update_one :mongo, @users, %{"id": user}, %{"$inc": %{"xp": amount}}, @update_args
  end

  def set_xp(user, amount) when is_integer(amount) do
    user = handle_in user
    Mongo.update_one :mongo, @users, %{"id": user}, %{"$set": %{"xp": amount}}, @update_args
  end

  # Guild levels #

  def get_guild_xp(user, guild) do
    user = handle_in(user) |> Integer.to_string
    guild = handle_in guild
    # TODO: Nested documents
    if is_nil guild["xp"][user] do
      set_guild_xp user, guild, 0
      0
    else
      -1
    end
  end

  def increment_guild_xp(user, guild, amount) when is_integer(amount) do
    user = handle_in(user) |> Integer.to_string
    guild = handle_in guild
    Mongo.update_one :mongo, @guilds, %{"id": guild}, %{"$inc": %{"xp.#{user}": amount}}, @update_args
    # TODO: Nested documents
  end

  def set_guild_xp(user, guild, amount) when is_integer(amount) do
    user = handle_in(user) |> Integer.to_string
    guild = handle_in guild
    # TODO: Nested documents
    Mongo.update_one :mongo, @guilds, %{"id": guild}, %{"$set": %{"xp.#{user}": amount}}, @update_args
  end

  # TODO: Per-guild levels #

  ####################
  # Emote operations #
  ####################

  def get_emotes(name) when is_binary(name) do
    # TODO: Magic constant from cache.ex, uses cache pool
    Mongo.aggregate :mongo_cache, "emoji_cache", [
        %{"$match": %{"name": name}},
        %{"$sort": %{"guild_id": 1}}
      ], pool: DBConnection.Poolboy
  end

  ##########################################
  ## INTERNAL API STARTS BEYOND THIS LINE ##
  ##                                      ##
  ## UNLESS YOU ARE CHASING DOWN A BUG,   ##
  ## THIS IS MOST DEFINITELY NOT WHAT YOU ##
  ## WANT TO BE TOUCHING!                 ##
  ##########################################

  #####################################################################################################################

  ####################
  # Helper functions #
  ####################

  defp handle_in(entity) do
    # Can't case here :^(
    if is_map(entity) do
      handle_in(entity["id"])
    else
      if is_binary(entity) do
        String.to_integer(entity)
      else
        if is_integer(entity) do
          entity
        else
          raise "Invalid DB entity input: #{inspect entity}"
        end
      end
    end
  end
end