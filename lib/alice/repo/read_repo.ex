defmodule Alice.ReadRepo do
  use Ecto.Repo, otp_app: :alice

  import Ecto.Query

  def get_user(id) do
    Alice.User |> where([u], u.user_id == ^id)
               |> Alice.ReadRepo.one
  end

  def balance(user) do
    user_id = user["id"]
    bal = Alice.User
          |> where([u], u.user_id == ^user_id)
          |> select([:balance])
          |> Alice.WriteRepo.one
    if is_nil bal do
      Alice.WriteRepo.create_base_user user
      0
    else
      bal
    end
  end
end
