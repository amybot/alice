defmodule Alice.Cmd.Utility do
  use Annotatable, [:command]

  import Emily.Embed
  import Alice.Util

  @command %{name: "ping", desc: "command.desc.util.ping"}
  def ping(_name, _args, _argstr, ctx) do
    e = embed()
        |> desc("pong!")
    now = :os.system_time :millisecond
    {:ok, msg} = Emily.create_message ctx["channel_id"], [content: nil, embed: e]
    then = :os.system_time :millisecond
    Emily.edit_message ctx["channel_id"], msg["id"], [content: nil, embed: embed() |> desc("pong! (#{then - now}ms)")]
  end

  @command %{name: "help", desc: "command.desc.util.help"}
  def help(_name, _args, _argstr, ctx) do
    e = ctx
        |> ctx_embed
        |> field("Commands", "https://amy.chat/commands", false)
        |> field("Dashboard", "https://amy.chat/login", false)
        |> field("Support server", "https://amy.chat/support", false)
        |> field("Bot invite", "https://amy.chat/invite", false)
        |> field("Donate", "https://amy.chat/donate", false)
    Emily.create_message ctx["channel_id"], [content: nil, embed: e]
  end

  @command %{name: "invite", desc: "command.desc.util.invite"}
  def invite(_name, _args, _argstr, ctx) do
    e = ctx
        |> ctx_embed
        |> field("Bot invite", "https://amy.chat/invite", false)
    Emily.create_message ctx["channel_id"], [content: nil, embed: e]
  end
end