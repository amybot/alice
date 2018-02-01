defmodule Alice.Cmd.Music do
  use Annotatable, [:command]
  use Timex
  import Emily.Embed
  import Alice.Util
  require Logger

  # Note: This module is kind of a mess because of the differences in what 
  # JDA-A vs. my lib. require for ex. snowflake format.

  # TODO: Enforce 5 seconds between leave / join to avoid errors. Apparently we can't even get voice events when it's too fast...

  @command %{name: "join", desc: "command.desc.music.join"}
  def join(_name, _args, _argstr, ctx) do
    id = ctx["author"]["id"]
    user_vc = Alice.Cache.get_voice_channel id
    lang = ctx["channel_id"] |> Alice.Cache.channel_to_guild_id 
                             |> Alice.Database.get_language

    # TODO: Compare guilds too...

    if is_nil user_vc do
      # User not in vc
      ctx |> error(Alice.I18n.translate(lang, "command.music.join.failure.user-not-in-voice"))
          |> Emily.create_message(ctx["channel_id"])
    else
      self_state = Alice.Cache.get_self_voice_state_channel(user_vc)
      self_vc = self_state["channel_id"] # Alice.Shard.get_self_id() |> Alice.Cache.get_voice_channel
      # User in vc, check ourself
      if is_nil self_vc do
        # We aren't in voice, probs good
        _res = Alice.Hotspring.open_connection ctx["author"], Integer.to_string(user_vc), Integer.to_string(ctx["channel_id"])
        channel_name = Alice.Cache.get_channel_name user_vc
        msg = Alice.I18n.translate(lang, "command.music.join.success") |> String.replace("$channel", channel_name)
        ctx
        |> ctx_embed
        |> title("Music")
        |> desc(msg)
        |> Emily.create_message(ctx["channel_id"])
      else
        # We are in voice, work out correct error
        if self_vc == user_vc do
          ctx |> error(Alice.I18n.translate(lang, "command.music.join.failure.bot-in-same-voice"))
              |> Emily.create_message(ctx["channel_id"])
        else
          ctx |> error(Alice.I18n.translate(lang, "command.music.join.failure.bot-already-in-voice"))
              |> Emily.create_message(ctx["channel_id"])
        end
      end
    end
  end

  @command %{name: "leave", desc: "command.desc.music.leave"}
  def leave(_name, _args, _argstr, ctx) do
    id = ctx["author"]["id"]
    user_vc = Alice.Cache.get_voice_channel id
    lang = ctx["channel_id"] |> Alice.Cache.channel_to_guild_id 
                             |> Alice.Database.get_language

    if is_nil user_vc do
      # User not in voice, not good
      ctx |> error(Alice.I18n.translate(lang, "command.music.leave.failure.user-not-in-voice"))
          |> Emily.create_message(ctx["channel_id"])
    else
      self_vc = Alice.Cache.get_self_voice_state_channel(user_vc) |> Access.get("channel_id") # Alice.Shard.get_self_id() |> Alice.Cache.get_voice_channel
      if is_nil self_vc do
        # Bot not in vc
        ctx |> error(Alice.I18n.translate(lang, "command.music.leave.failure.bot-not-in-channel"))
            |> Emily.create_message(ctx["channel_id"])
      else
        # Bot in vc, check user
        if self_vc == user_vc do
          # User in same vc, leave
          {_hotspring, _shard} = Alice.Hotspring.close_connection ctx["author"], Integer.to_string(ctx["channel_id"])
          channel_name = Alice.Cache.get_channel_name user_vc
          msg = Alice.I18n.translate(lang, "command.music.leave.success") |> String.replace("$channel", channel_name)
          ctx
          |> ctx_embed
          |> title("Music")
          |> desc(msg)
          |> Emily.create_message(ctx["channel_id"])
        else
          # User in diff. vc, error
          ctx |> error(Alice.I18n.translate(lang, "command.music.leave.failure.bot-in-different-channel"))
              |> Emily.create_message(ctx["channel_id"])
        end
      end
    end
  end

  @command %{name: "queue", desc: "command.desc.music.queue"}
  def queue(_name, args, argstr, ctx) do
    lang = ctx["channel_id"] |> Alice.Cache.channel_to_guild_id 
                             |> Alice.Database.get_language
    if length(args) > 0 do
      if hd(args) |> String.downcase() == "length" do
        res = Alice.Hotspring.queue_length ctx["author"], Integer.to_string(ctx["channel_id"])
        msg = Alice.I18n.translate(lang, "command.music.queue.length") |> String.replace("$length", Integer.to_string(res["length"]))
        ctx
        |> ctx_embed
        |> title("Music")
        |> desc(msg)
        |> Emily.create_message(ctx["channel_id"])
      else
        _res = Alice.Hotspring.queue ctx["author"], Integer.to_string(ctx["channel_id"]), argstr
      end
    else
      ctx
      |> error(Alice.I18n.translate(lang, "command.music.queue.failure"))
      |> Emily.create_message(ctx["channel_id"])
    end
  end

  @command %{name: "play", desc: "command.desc.music.play"}
  def play(_name, args, argstr, ctx) do
    if length(args) > 1 do
      _hotspring = Alice.Hotspring.play ctx["author"], Integer.to_string(ctx["channel_id"]), argstr
    else
      _hotspring = Alice.Hotspring.start_queue ctx["author"], Integer.to_string(ctx["channel_id"])
    end
  end

  @command %{name: "skip", desc: "command.desc.music.skip"}
  def skip(_name, args, argstr, ctx) do
    lang = ctx["channel_id"] |> Alice.Cache.channel_to_guild_id 
                             |> Alice.Database.get_language
    try do
      head = args |> hd
      amount = unless String.downcase(head) == "all" do
              head |> String.to_integer 
            else
              -1
            end
      Alice.Hotspring.skip ctx["author"], Integer.to_string(ctx["channel_id"]), amount
      res = Alice.I18n.translate(lang, "command.music.skip.success")
          |> String.replace("$amount", hd(args))
      ctx
      |> ctx_embed
      |> title("Music")
      |> desc(res)
      |> Emily.create_message(ctx["channel_id"])
    rescue
      e ->
        res = Alice.I18n.translate(lang, "command.music.skip.failure.invalid-number")
            |> String.replace("$amount", hd(args))
        ctx
        |> error(res)
        |> Emily.create_message(ctx["channel_id"])
    end
  end

  @command %{name: "np", desc: "command.desc.music.np"}
  def np(_name, _args, _argstr, ctx) do
    # TODO: Track position, visualization of time?
    data = Alice.Hotspring.np ctx["author"], Integer.to_string(ctx["channel_id"])
    info = data["info"]
    length = Duration.from_milliseconds info["length"]
    data
    |> track_event_embed
    |> title("Now playing")
    |> url(info["uri"])
    |> field("Title", info["title"], true)
    |> field("Artist", info["author"], true)
    |> field("Length", "#{Timex.format_duration length, :humanized}", true)
    |> Emily.create_message(ctx["channel_id"])
  end
end