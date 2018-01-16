defmodule Alice.WriteRepo.Migrations.CreateUser do
  @moduledoc """
  Initial user table.
  """

  use Ecto.Migration

  def up do
    create table(:amybot_users, primary_key: false) do
      add :user_id,   :decimal, primary_key: true
      add :balance,   :integer
      add :global_xp, :integer
    end
    create index(:amybot_users, [:user_id])
  end
end
