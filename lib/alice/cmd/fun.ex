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
end