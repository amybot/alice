defmodule Alice.ReadRepo do
  use Ecto.Repo, otp_app: :alice
  require Logger
  import Ecto.Query

  def get_user(id) do
    Alice.User |> where([u], u.user_id == ^id)
               |> Alice.ReadRepo.one
  end

  def balance(user) do
    user_id = user["id"]
    res = Alice.User
          |> where([u], u.user_id == ^user_id)
          |> select([:balance])
          |> Alice.ReadRepo.one
    # If no user stored in the db, insert a new one and return nothing
    # This is done here so that we don't have this scattered all over our base
    # application code.
    if is_nil res do
      Alice.WriteRepo.create_base_user user
      0
    else
      res.balance
    end
  end

  def balance_top do
    Alice.User
    |> select([:user_id, :balance])
    |> order_by(desc: :balance)
    |> limit(10)
    |> Alice.ReadRepo.all
  end
end
