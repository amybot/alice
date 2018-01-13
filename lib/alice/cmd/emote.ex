defmodule Alice.Cmd.Emote do
  use Annotatable, [:command]

  #def command("bap" = name, args, argstr, ctx), do: emote(name, args, argstr, ctx)
  #def command("chew" = name, args, argstr, ctx), do: emote(name, args, argstr, ctx)
  #def command("cookie" = name, args, argstr, ctx), do: emote(name, args, argstr, ctx)
  #def command("hug" = name, args, argstr, ctx), do: emote(name, args, argstr, ctx)
  #def command("lick" = name, args, argstr, ctx), do: emote(name, args, argstr, ctx)
  #def command("nom" = name, args, argstr, ctx), do: emote(name, args, argstr, ctx)
  #def command("poke" = name, args, argstr, ctx), do: emote(name, args, argstr, ctx)
  #def command("prod" = name, args, argstr, ctx), do: emote(name, args, argstr, ctx)
  #def command("shoot" = name, args, argstr, ctx), do: emote(name, args, argstr, ctx)
  #def command("stab" = name, args, argstr, ctx), do: emote(name, args, argstr, ctx)
  #def command("tickle" = name, args, argstr, ctx), do: emote(name, args, argstr, ctx)

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