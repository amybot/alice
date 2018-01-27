defmodule Alice.Cmd.Dnd do
  use Annotatable, [:command]
  import Emily.Embed
  import Alice.Util
  require Logger

  @command %{name: "roll", desc: "commands.desc.dnd.roll"}
  def roll(_name, _args, argstr, ctx) do
    res = Alice.Dice.roll_dice argstr
    ctx |> ctx_embed
        |> title("Roll")
        |> desc("Rolled: #{inspect res}")
        |> Emily.create_message(ctx["channel_id"])
  end
end