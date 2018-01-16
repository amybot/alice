defmodule Alice.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:user_id, :decimal, autogenerate: false}
  schema "amybot_users" do
    field :balance,   :integer
    field :global_xp, :integer
  end

  ##############
  # Ecto utils #
  ##############

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, [:balance, :global_xp])
    |> validate_number(:balance, greater_than_or_equal_to: 0)
    |> validate_number(:global_xp, greater_than_or_equal_to: 0)
  end

  def get_base_changeset(entity) do
    changeset get_base_user(entity)
  end

  ################
  # External API #
  ################

  def get_id_only_user(entity) do
    user = %Alice.User{}
    %{user | user_id: entity["id"]}
  end

  def get_base_user(entity) do
    user = %Alice.User{}
    %{user | user_id: entity["id"], balance: 0, global_xp: 0}
  end
end