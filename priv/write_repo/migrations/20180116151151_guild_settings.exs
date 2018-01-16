defmodule Alice.WriteRepo.Migrations.GuildSettings do
  @moduledoc """
  Add initial guild settings table
  """

  use Ecto.Migration

  def change do
    create table(:amybot_guild_settings, primary_key: false) do
      add :guild_id,          :decimal,          primary_key: true
      add :prefix,            :string,           null: true
      add :disabled_commands, {:array, :string}, null: true
    end
    create index(:amybot_guild_settings, [:guild_id])
  end
end
