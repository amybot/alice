defmodule Alice.Cmd.Music do
  use Annotatable, [:command]
  import Emily.Embed
  import Alice.Util
  require Logger

  @command %{name: "join", desc: "command.desc.music.join"}
  def join(_name, _args, _argstr, ctx) do
    id = ctx["author"]["id"]
    state = Alice.Cache.get_voice_state id
    if is_nil state do
      ctx |> error("No voice state :(")
          |> Emily.create_message(ctx["channel_id"])
    else
      channel_id = state["channel_id"]
      guild_id = unless is_nil state["guild_id"] do
              state["guild_id"]
            else
              Alice.Cache.channel_to_guild_id channel_id
            end
      res = Alice.Hotspring.open_connection guild_id, channel_id
      embed()
      |> title("Hotspring response")
      |> desc("""
              ```Elixir
              #{inspect res, pretty: true}
              ```
              """)
      |> color(0xFF69B4)
      |> Emily.create_message(ctx["channel_id"])
    end
  end

  @command %{name: "leave", desc: "command.desc.music.leave"}
  def leave(_name, _args, _argstr, ctx) do
    id = Alice.Shard.get_self()["id"]
    state = Alice.Cache.get_voice_state id
    if is_nil state do
      ctx |> error("No voice state :(")
          |> Emily.create_message(ctx["channel_id"])
    else
      channel_id = state["channel_id"]
      guild_id = unless is_nil state["guild_id"] do
              state["guild_id"]
            else
              Alice.Cache.channel_to_guild_id channel_id
            end
      {hotspring, shard} = Alice.Hotspring.close_connection id, guild_id
      embed()
      |> field("Hotspring response", """
              ```Elixir
              #{inspect hotspring, pretty: true}
              ```
              """, false)
      |> field("Shard response", """
              ```Elixir
              #{inspect shard, pretty: true}
              ```
              """, false)
      |> color(0xFF69B4)
      |> Emily.create_message(ctx["channel_id"])
    end
  end

  @command %{name: "play", desc: "command.desc.music.play"}
  def play(_name, _args, argstr, ctx) do
    embed()
    |> field("Hotspring response", "Attempting to play: #{argstr}", false)
    |> color(0xFF69B4)
    |> Emily.create_message(ctx["channel_id"])
    hotspring = Alice.Hotspring.play(argstr, ctx["channel_id"])
    embed()
    |> field("Hotspring response", """
            ```Elixir
            #{inspect hotspring, pretty: true}
            ```
            """, false)
    |> color(0xFF69B4)
    |> Emily.create_message(ctx["channel_id"])
  end
end