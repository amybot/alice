defmodule Alice.WriteRepo.Migrations.EmoteCache do
  @moduledoc """
  Table for storing / querying emote cache
  """

  use Ecto.Migration

  def change do
    create table(:amybot_emote_cache, primary_key: false) do
      add :guild_id,   :decimal, primary_key: true
      add :emote_id,   :decimal
      add :emote_name, :string
    end
    create index(:amybot_emote_cache, [:guild_id, :emote_id, :emote_name])
  end
end
