defmodule Alice.WriteRepo do
  use Ecto.Repo, otp_app: :alice
  import Ecto.Query

  ################
  # External API #
  ################

  @doc """
  Inserts the base user into the db. Will not overwrite on conflict.
  """
  def create_base_user(entity) do
    user = Alice.User.get_base_changeset entity
    insert! user, [on_conflict: :nothing]
  end

  def prune_emotes(guild) do
    from("amybot_emote_cache")
    |> where(guild_id: ^guild)
    |> delete_all
  end

  def update_balance(entity, amount) do
    user = Alice.User.get_id_only_user entity
    cs = Alice.User.changeset(user, %{
        balance: amount
      })
    update! cs
  end

  def increment_balance(entity, amount) do
    user_id = entity["id"]
    user = Alice.ReadRepo.get_user user_id
    old_bal = user.balance
    update_balance entity, old_bal + amount
  end
end
