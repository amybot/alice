defmodule Alice.WriteRepo.Migrations.EmoteCache do
  @moduledoc """
  Table for storing / querying emote cache
  """

  use Ecto.Migration

  def change do
    create table(:amybot_emote_cache, primary_key: false) do
      add :guild_id,       :decimal
      add :id,             :decimal
      add :name,           :string
      add :require_colons, :boolean
      add :managed,        :boolean
      add :animated,       :boolean
    end
    create index(:amybot_emote_cache, [:guild_id, :id, :name])
  end
end
