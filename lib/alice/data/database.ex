defmodule Alice.Database do
  @users "users"
  @guilds "guilds"

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

  def get_user(user) do
    user = handle_in user
    Mongo.find_one :mongo, @users, %{"id": user}, pool: DBConnection.Poolboy
  end

  def increment_balance(user, amount) when is_integer(amount) do
    user = handle_in user
    Mongo.update_one :mongo, @users, %{"id": user}, 
      %{"$inc": %{"balance": amount}}, [pool: DBConnection.Poolboy, upsert: true]
  end

  def set_balance(user, amount) when is_integer(amount) do
    user = handle_in user
    Mongo.update_one :mongo, @users, %{"id": user}, 
      %{"$set": %{"balance": amount}}, [pool: DBConnection.Poolboy, upsert: true]
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
end