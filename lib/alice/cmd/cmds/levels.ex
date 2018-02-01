defmodule Alice.Cmd.Levels do
  use Annotatable, [:command]
  import Emily.Embed
  import Alice.Util
  alias Lace.Redis
  require Logger

  @command %{name: "rank", desc: "command.desc.levels.rank"}
  def rank(_name, args, _argstr, ctx) do
    # TODO: Make this not no-op. Blocking on per-guild levels being finished
    user = ctx["author"]
    guild = Alice.Cache.channel_to_guild_id ctx["channel_id"]
    guild_obj = Alice.Cache.get_guild guild
    xp = Alice.Database.get_guild_xp user, guild
    level = Alice.LevelsHandler.xp_to_level xp
    ctx |> ctx_embed
        |> title("#{user["username"]}'s #{guild_obj["name"]} rank")
        |> field("XP", "#{inspect xp}", false)
        |> field("Level", "#{inspect level}", false)
        |> Emily.create_message(ctx["channel_id"])
  end

  @command %{name: "levels", desc: "command.desc.levels.levels"}
  def levels(_name, _args, _argstr, ctx) do
    # TODO: Make this not no-op. Blocking on per-guild levels being finished
    guild = Alice.Cache.channel_to_guild_id ctx["channel_id"]
    guild_obj = Alice.Cache.get_guild guild
    ctx |> ctx_embed
        |> title("#{guild_obj["name"]} rank leaderboards")
        |> desc("https://amy.chat/levels/#{inspect guild}")
        |> Emily.create_message(ctx["channel_id"])
  end

  @command %{name: "profile", desc: "command.desc.levels.profile"}
  def profile(_name, _args, _argstr, _ctx) do
    ;
  end
end