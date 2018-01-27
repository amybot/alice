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

  @command %{name: "lang", desc: "command.desc.util.lang"}
  def lang(_name, args, argstr, ctx) do
    if length(args) == 0 do
      langs = Alice.I18n.get_langs()
      txt = langs
            |> Enum.map(fn(x) -> "`#{x}` - #{Alice.I18n.translate(x, "name")}\n" end)
            |> Enum.reduce("", fn(x, acc) -> 
                acc <> x
              end)
      ctx
      |> ctx_embed
      |> title("Available languages")
      |> desc(txt)
      |> Emily.create_message( ctx["channel_id"])
    else
      guild = ctx["channel_id"] |> Alice.Cache.channel_to_guild_id
      lang = Alice.Database.get_language guild
      {res, msg} = Alice.Database.set_language guild, argstr
      if res == :ok do
        ctx
        |> ctx_embed
        |> title("Language changed!")
        |> desc(Alice.I18n.translate(lang, "command.util.lang.success") |> String.replace("$lang", argstr))
        |> Emily.create_message( ctx["channel_id"])
      else
        ctx
        |> error(Alice.I18n.translate(lang, "command.util.lang.failure") |> String.replace("$lang", argstr))
        |> Emily.create_message( ctx["channel_id"])
      end
    end
  end
end