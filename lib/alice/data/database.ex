defmodule Alice.Database do
  @users "users"
  @guilds "guilds"

  @update_args [pool: DBConnection.Poolboy, upsert: true]

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
    xp = get_user(user)
    if is_nil user do
      set_xp user, 0
      0
    else
      xp
    end
  end

  def get_guild_xp(user, guild) do
    user = handle_in user
    # TODO: Nested documents
  end

  def increment_xp(user, amount) when is_integer(amount) do
    user = handle_in user
    Mongo.update_one :mongo, @users, %{"id": user}, %{"$inc": %{"xp": amount}}, @update_args
  end

  def increment_guild_xp(user, guild, amount) when is_integer(guild) and is_integer(amount) do
    user = handle_in user
    # TODO: Nested documents
  end

  def set_xp(user, amount) when is_integer(amount) do
    user = handle_in user
    Mongo.update_one :mongo, @users, %{"id": user}, %{"$set", %{"xp": amount}}, @update_args
  end

  def set_guild_xp(user, guild, amount) when is_integer(guild) and is_integer(amount) do
    user = handle_in user
    # TODO: Nested documents
    Mongo.update_one :mongo, @guilds, %{"id": user}, %{"$inc": %{"xp": amount}}, @update_args
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

  defp handle_in(user) do
    # Can't case here :^(
    if is_map(user) do
      handle_in(user["id"])
    else
      if is_binary(user) do
        String.to_integer(user)
      else
        if is_integer(user) do
          user
        else
          raise "Invalid DB user input: #{inspect user}"
        end
      end
    end
  end

end