defmodule Alice.Guild do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:guild_id, :decimal, autogenerate: false}
  schema "amybot_guild_settings" do
    field :prefix,            :string
    field :disabled_commands, {:array, :string}
  end

  ##############
  # Ecto utils #
  ##############

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, [:prefix, :disabled_commands])
    |> validate_change(:prefix, fn :prefix, prefix -> 
        if prefix == "amy!" do
          [prefix: "Cannot be amy!"]
        else
          []
        end
      end)
  end
end