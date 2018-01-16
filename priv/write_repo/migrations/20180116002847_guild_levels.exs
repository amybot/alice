defmodule Alice.WriteRepo.Migrations.GuildLevels do
  @moduledoc """
  Per-guild levels
  """

  use Ecto.Migration
  @disable_ddl_transaction true

  def up do
    create table(:amybot_levels, primary_key: false) do
      add :guild_id,     :decimal, primary_key: true
      add :user_id,      :decimal
      add :user_name,    :string
      add :user_discrim, :string
      add :xp,           :integer
    end
    create index(:amybot_levels, [:guild_id])
    create index(:amybot_levels, [:user_id])
  end
end
