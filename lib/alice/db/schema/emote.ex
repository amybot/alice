defmodule Alice.Emote do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:guild_id, :decimal, autogenerate: false}
  schema "amybot_emote_cache" do
    field :emote_id,   :decimal
    field :emote_name, :string
  end

  ##############
  # Ecto utils #
  ##############

  def changeset(emote, params \\ %{}) do
    emote
    |> cast(params, [:emote_name])
    |> validate_change(:emote_name, fn :emote_name, name -> 
        if String.length(name) do
          [name: "Name must be >= 2 characters."]
        else
          []
        end
      end)
  end
end