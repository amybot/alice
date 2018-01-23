defmodule Alice.Cmd.Emote do
  use Annotatable, [:command]

  import Alice.Util
  import Emily.Embed

  @command [
    %{name: "bap", desc: "command.desc.emote.bap"},
    %{name: "chew", desc: "command.desc.emote.chew"},
    %{name: "cookie", desc: "command.desc.emote.cookie"},
    %{name: "hug", desc: "command.desc.emote.hug"},
    %{name: "lick", desc: "command.desc.emote.lick"},
    %{name: "nom", desc: "command.desc.emote.nom"},
    %{name: "poke", desc: "command.desc.emote.poke"},
    %{name: "prod", desc: "command.desc.emote.prod"},
    %{name: "shoot", desc: "command.desc.emote.shoot"},
    %{name: "stab", desc: "command.desc.emote.stab"},
    %{name: "tickle", desc: "command.desc.emote.tickle"},
  ]
  def emote(name, args, argstr, ctx) do
    if argstr == "" or length(args) == 0 do
      Emily.create_message ctx["channel_id"], [content: nil, 
          embed: error(ctx, Alice.I18n.missing_arg("en", name, "target"))]
    else
      unless ctx["mention_everyone"] 
          or String.contains?(argstr, "@everyone") 
          or String.contains?(argstr, "@here") do
        response = Alice.I18n.translate("en", "command.emote.#{name}")
                   |> String.replace("$sender", ctx["author"]["username"])
                   |> String.replace("$target", argstr)
        ctx
        |> ctx_embed
        |> desc(response)
        |> Emily.create_message(ctx["channel_id"])
      else
        Emily.create_message ctx["channel_id"], [content: nil, embed: error(ctx, Alice.I18n.translate("en", "message.no-ping-everyone"))]
      end
    end
  end
end