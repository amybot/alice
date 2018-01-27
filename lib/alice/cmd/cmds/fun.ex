defmodule Alice.Cmd.Fun do
  use Annotatable, [:command]

  import Emily.Embed
  import Alice.Util

  require Logger

  @command %{name: "sb", desc: "command.desc.fun.sb"}
  def sb(name, args, argstr, ctx) do
    if length(args) == 0 do
      err = Alice.I18n.missing_arg("en", name, "message")
      Emily.create_message ctx["channel_id"], [content: nil, embed: error(ctx, err)]
    else
      response = argstr
                 |> String.graphemes
                 |> Enum.reduce(%{idx: 0, res: ""}, fn(x, acc) -> 
                    c = if rem(acc[:idx], 2) == 0 do
                          String.upcase(x)
                        else
                          String.downcase(x)
                        end
                    %{idx: acc[:idx] + 1, res: acc[:res] <> c}
                  end)
      embed = ctx
              |> ctx_embed
              |> title(response[:res])
              |> image("http://i0.kym-cdn.com/entries/icons/original/000/022/940/spongebobicon.jpg")
      Emily.create_message ctx["channel_id"], [content: nil, embed: embed]
    end
  end

  @command %{name: "evil", desc: "command.desc.fun.evil"}
  def evil(name, args, argstr, ctx) do
    if length(args) == 0 do
      err = Alice.I18n.missing_arg("en", name, "message")
      Emily.create_message ctx["channel_id"], [content: nil, embed: error(ctx, err)]
    else
      embed = ctx
              |> ctx_embed
              |> title(argstr)
              |> image("https://i.imgur.com/YZWYH2w.png")
      Emily.create_message ctx["channel_id"], [content: nil, embed: embed]
    end
  end

  @command [
    %{name: "cat", desc: "command.desc.fun.cat"},
    %{name: "dog", desc: "command.desc.fun.dog"},
    %{name: "catgirl", desc: "command.desc.fun.catgirl"},
    %{name: "rubeface", desc: "command.desc.fun.rubeface"},
    %{name: "fatsquare", desc: "command.desc.fun.fatsquare"},
  ]
  def image(name, args, _argstr, ctx) do
    nsfw = name == "catgirl" and length(args) > 0 and String.downcase(hd(args)) == "nsfw"
    title = if nsfw do
              "#{String.capitalize(name)} (NSFW)"
            else
              String.capitalize(name)
            end
    # TODO: Ewwwwwwwww
    embed = if nsfw do
              if Alice.Cache.is_nsfw ctx["channel_id"] do
                url = Alice.ApiClient.image name, nsfw
                ctx
                |> ctx_embed
                |> title(title)
                |> image(url)
              else
                err = Alice.I18n.translate("en", "message.no-nsfw")
                error ctx, err
              end
            else
              url = Alice.ApiClient.image name, nsfw
              ctx
              |> ctx_embed
              |> title(title)
              |> image(url)
            end
    Emily.create_message ctx["channel_id"], [content: nil, embed: embed]
  end

  @command %{name: "e", desc: "command.desc.fun.e"}
  def emote(_name, _args, argstr, ctx) do
    emote_idx = Regex.run ~r/-\d+$/, argstr
    emote = unless is_nil emote_idx do
              String.replace argstr, hd(emote_idx), ""
            else
              argstr
            end
    emotes = Alice.Database.get_emotes emote
    res = if is_nil emote_idx do
            Enum.random emotes
          else
            idx = emote_idx |> hd |> String.to_integer |> abs
            emote_at = Enum.at emotes, idx
            if is_nil emote_at do
              Enum.random emotes
            else
              emote_at
            end
          end
    title = if is_nil emote_idx do
              ":#{emote}:"
            else
              ":#{emote}#{emote_idx}:"
            end
    ctx
    |> ctx_embed
    |> title(title)
    |> image("https://cdn.discordapp.com/emojis/#{res["id"]}.png")
    |> Emily.create_message(ctx["channel_id"])
  end
end