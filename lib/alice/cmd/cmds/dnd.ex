defmodule Alice.Cmd.Dnd do
  use Annotatable, [:command]
  import Emily.Embed
  import Alice.Util
  require Logger
  alias Alice.ApiClient

  @spell_classes ["bard", "cleric", "druid", "paladin", "ranger", "sorcerer", "warlock", "wizard"]

  @command %{name: "roll", desc: "commands.desc.dnd.roll"}
  def roll(_name, _args, argstr, ctx) do
    res = Alice.Dice.roll_dice argstr
    case res do
      {:error, msg} ->
        ctx |> error(msg)
            |> Emily.create_message(ctx["channel_id"])
      _ ->
        ctx |> ctx_embed
            |> title("Roll")
            |> desc("Rolled: #{inspect res}")
            |> Emily.create_message(ctx["channel_id"])
    end
  end

  @command %{name: "dnd", desc: "command.desc.dnd.dnd"}
  def dnd(_name, args, argstr, ctx) do
    if length(args) < 2 do
      ctx |> error("You need to search for a specific type of thing!")
          |> Emily.create_message(ctx["channel_id"])
    else
      split = String.split(argstr, ~r/\s+/, [parts: 2, trim: true])
      type = hd split
      query = split |> tl |> Enum.join(" ")
      res = ApiClient.dnd(type, query)
      exact_matches = res |> Enum.filter(fn(x) -> String.downcase(x["name"]) == String.downcase(query) end) |> Enum.to_list
      exact = exact_matches |> length
      if exact == 1 do
        # Have an exact match, use it
        match = hd exact_matches
        case type do
          "monster" -> send_monster(ctx, match)
          "spell" -> send_spell(ctx, match)
          "item" -> send_item(ctx, match)
          "magicitem" -> send_magic_item(ctx, match)
          "race" -> :ok
          "feat" -> :ok
        end
      else
        if length(res) > 1 do
          # Too many matches
          cls = query |> String.split |> hd
          names = res |> Enum.map(fn(x) -> x["name"] end)
          if cls in @spell_classes do
            # It's a spell class
            ctx |> ctx_embed
                |> title("Matching spells")
                |> desc("* " <> Enum.join(names, "\n* "))
                |> Emily.create_message(ctx["channel_id"])
          else
            ctx |> error("Too many matches")
                |> field("Matches:", "* " <> Enum.join(names, "\n* "), false)
                |> Emily.create_message(ctx["channel_id"])
          end
        else
          # Single match
          ctx |> ctx_embed
              |> title("Single result!")
              |> desc("Single result :O")
              |> Emily.create_message(ctx["channel_id"])
        end
      end
    end
  end

  defp send_item(ctx, data) do
    e = ctx |> ctx_embed
            |> title(data["name"])
            |> field("Type / Property", "#{data["type"]} / #{data["property"]}", false)
            |> field("Value", data["value"], false)
            |> Emily.create_message(ctx["channel_id"])
            
    text = data["text"]
    unless is_nil text do
      text = if is_map text do
                  [text]
                else
                  text
                end
      e = ctx |> ctx_embed |> title(data["name"])
      {e, _} = text |> Enum.reduce({e, 1}, fn(x, {acc, c}) ->
                  z = acc |> field("Text #{inspect c}", x, false)
                  {z, c + 1}
                end)
      e |> Emily.create_message(ctx["channel_id"])
    end 
  end

  defp send_magic_item(ctx, data) do
    e = ctx |> ctx_embed
            |> title(data["name"])
            |> field("Type / Property", "#{data["type"]} / #{data["property"]}", false)
            |> field("Rarity", data["rarity"], false)
            |> Emily.create_message(ctx["channel_id"])

    text = data["text"]
    unless is_nil text do
      text = if is_map text do
                  [text]
                else
                  text
                end
      e = ctx |> ctx_embed |> title(data["name"])
      {e, _} = text |> Enum.reduce({e, 1}, fn(x, {acc, c}) ->
                  z = acc |> field("Text #{inspect c}", x, false)
                  {z, c + 1}
                end)
      e |> Emily.create_message(ctx["channel_id"])
    end 
  end

  defp send_spell(ctx, data) do
    # Base info
    ctx |> ctx_embed
        |> title(data["name"])
        |> field("Type", data["school"], false)
        |> field("Class(es)", data["classes"], false)
        |> field("Level", data["level"], false)
        |> field("Range", data["range"], false)
        |> field("Casting time", data["time"], false)
        |> field("Duration", data["duration"], false)
        |> field("Components", data["components"], false)
        |> Emily.create_message(ctx["channel_id"])
    # Text
    text = data["text"]
    unless is_nil text do
      text = if is_map text do
                  [text]
                else
                  text
                end
      e = ctx |> ctx_embed |> title(data["name"])
      {e, _} = text |> Enum.reduce({e, 1}, fn(x, {acc, c}) ->
                  z = acc |> field("Text #{inspect c}", x, false)
                  {z, c + 1}
                end)
      e |> Emily.create_message(ctx["channel_id"])
    end
  end

  defp send_monster(ctx, data) do
    # Base info
    ctx |> ctx_embed
        |> title(data["name"])
        |> field("Type", data["type"], false)
        |> field("Size", data["size"], false)
        |> field("Alignment", data["alignment"], false)
        |> field("HP and AC", "#{data["hp"]} HP, #{data["ac"]} AC\n**#{data["save"]}**", false)
        |> field("Speed", data["speed"], false)
        # wew
        |> field("Ability scores", "**STR**: #{data["str"]}, **DEX**: #{data["dex"]}, **CON**: #{data["con"]}, "
                                  <> "**INT**: #{data["int"]}, **WIS**: #{data["wis"]}, **CHA**: #{data["cha"]}", false)
        |> field("Senses", data["senses"], false)
        |> field("Languages", data["languages"], false)
        |> field("CR", data["cr"], false)
        |> Emily.create_message(ctx["channel_id"])
    # Traits
    traits = data["trait"]
    unless is_nil traits do
      traits = if is_map traits do
                  [traits]
                else
                  traits
                end
      e = ctx |> ctx_embed |> title(data["name"])
      {e, _} = traits |> Enum.reduce({e, 1}, fn(x, {acc, c}) ->
                  z = acc
                      |> field("Trait #{inspect c}", "**#{x["name"]}**\n#{x["text"]}", false)
                  {z, c + 1}
                end)
      e |> Emily.create_message(ctx["channel_id"])
    end

    # Actions
    actions = data["action"]
    unless is_nil actions do
      actions = if is_map actions do
                  [actions]
                else
                  actions
                end
      e = ctx |> ctx_embed |> title(data["name"])
      {e, _} = actions |> Enum.reduce({e, 1}, fn(x, {acc, c}) ->
                  z = acc
                      |> field("Action #{inspect c}", "**#{x["name"]}**\n#{x["text"]}", false)
                  {z, c + 1}
                end)
      e |> Emily.create_message(ctx["channel_id"])
    end

    # Legendaries
    legendaries = data["legendary"]
    unless is_nil legendaries do
      legendaries = if is_map legendaries do
                  [legendaries]
                else
                  legendaries
                end
      e = ctx |> ctx_embed |> title(data["name"])
      {e, _} = legendaries |> Enum.reduce({e, 1}, fn(x, {acc, c}) ->
                  z = acc
                      |> field("Legendary action #{inspect c}", "**#{x["name"]}**\n#{x["text"]}", false)
                  {z, c + 1}
                end)
      e |> Emily.create_message(ctx["channel_id"])
    end
  end
end