defmodule Alice.Cmd.Currency do
  use Annotatable, [:command]

  import Emily.Embed
  import Alice.Util

  require Logger

  @command %{name: "balance", desc: "command.desc.currency.balance"}
  def balance(name, args, argstr, ctx) do
    user_id = ctx["id"]
    bal = Alice.ReadRepo.balance ctx["author"]
    embed = ctx
            |> ctx_embed
            |> title("Balance")
            |> desc("You have #{inspect bal}:white_flower:")
    Emily.create_message ctx["channel_id"], [content: nil, embed: embed]
  end
end