defmodule Alice.Command do
  @moduledoc """
  When creating commands, you should annotate them with `@command data`. 
  Command data is of the form:

  ```Elixir
  %{
    # Command names may not have whitespace, EVER.
    name: "command_name",
    # A short description of the command
    desc: "a command that does things. and also stuff",
  }
  ```
  You may also pass a list of mappings, if you want many commands on one 
  function.
  """

  import Alice.Util
  require Logger

  @channel_type %{
    "GUILD_TEXT" => 0,
    "DM" => 1,
    "GUILD_VOICE" => 2,
    "GROUP_DM" => 3,
    "GUILD_CATEGORY" => 4,
  }

  @prefix "amy@"

  def get_prefix do
    System.get_env("PREFIX") || @prefix
  end


  def process_message(ctx) do
    msg = ctx["content"]

    Logger.debug "Got message: #{inspect ctx, pretty: true}"
    # TODO: Remove this, testing-only~
    if ctx["author"]["id"] == "128316294742147072" do
      Logger.debug "Got owner msg"
      try do
        words = String.split msg, ~R/\s+/, [parts: 2, trim: true]
        cmd = words |> List.first
        channel = Alice.Cache.get_channel ctx["channel_id"]
        lang = Alice.Database.get_language channel["guild_id"]
        ctx = ctx |> Map.put("lang", lang)
        unless is_nil cmd do
          custom_prefix = Alice.Database.get_custom_prefix channel["guild_id"]

          {prefixed, prefix} = 
              if String.starts_with?(cmd, get_prefix()) do
                {true, get_prefix()}
              else
                unless is_nil custom_prefix do
                  if String.starts_with?(cmd, custom_prefix) do
                    {true, custom_prefix}
                  else
                    {false, nil}
                  end
                else
                  {false, nil}
                end
              end

          if prefixed do
            Logger.debug "Prefixed msg"
            cmd_name = cmd |> String.slice(String.length(prefix)..2048)
            argstr = if length(words) > 1 do
              words |> List.last
            else
              ""
            end
            args = if length(words) > 1 do
              words |> List.last |> String.split(~R/\s+/, [trim: true])
            else
              []
            end

            unless is_ratelimited? ctx["author"] do
              match = Alice.CommandState.get_command cmd_name
              unless is_nil match do
                invoke = match[:invoke]
                unless is_nil invoke do
                  try do
                    Logger.debug "Invoking #{cmd_name}"
                    invoke.(cmd_name, args, argstr, ctx)
                  rescue
                    e -> 
                      # TODO: Make this log into Sentry instead
                      Logger.warn Exception.format(:error, e)
                      err = ctx
                            |> error(
                              """
                              ```Elixir
                              #{Exception.format(:error, e)}
                              ```
                              """
                              )
                      Emily.create_message ctx["channel_id"], [content: nil, embed: err]
                  end
                else
                  Logger.warn "Caught nil invoke for #{cmd_name}!"
                end
              end
            else
              ctx
              |> error(Alice.I18n.translate(lang, "message.ratelimited"))
              |> Emily.create_message(ctx["channel_id"])
            end
          else
            # Not a command, send it elsewhere
            Alice.LevelsHandler.process_message ctx
          end
        end
      rescue
        e ->
          if ctx["author"]["id"] == 128316294742147072 and ctx["channel_id"] == 392216552059174913 do
            channel = Alice.Cache.get_channel ctx["channel_id"]
            err = ctx
                  |> error(
                    """
                    ```Elixir
                    c: #{inspect channel, pretty: true}

                    #{Exception.format(:error, e)}
                    ```
                    """
                    )
            Emily.create_message ctx["channel_id"], [content: nil, embed: err]
          end
      end
    end
  end

  defp is_ratelimited?(user) when is_map(user) do
    # 1 xp gain / minute
    case Hammer.check_rate("chat-command-ratelimit:#{inspect user["id"]}", 5000, 1) do # lol
      {:allow, _count} ->
        Logger.debug "Allowing chat command from #{inspect user, pretty: true} due to not hitting global ratelimit 'chat-command-ratelimit'."
        false
      {:deny, _limit} ->
        Logger.debug "Denying chat command from #{inspect user, pretty: true} due to hitting global ratelimit 'chat-command-ratelimit'."
        true
    end
  end
end
