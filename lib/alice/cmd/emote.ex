defmodule Alice.Cmd.Emote do
  use Annotatable, [:command]

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
    unless ctx["mention_everyone"] 
        or String.contains?(argstr, "@everyone") 
        or String.contains?(argstr, "@here") do
      res = "command.emote.#{name}"
      Emily.create_message ctx["channel_id"], res
    else
      Emily.create_message ctx["channel_id"], Alice.I18n.translate("en", "message.no-ping-everyone")
    end
  end
end