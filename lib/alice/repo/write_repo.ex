defmodule Alice.WriteRepo do
  use Ecto.Repo, otp_app: :alice

  def create_base_user(entity) do
    user = Alice.User.get_base_changeset entity
    insert! user, [on_conflict: :nothing]
  end
end
