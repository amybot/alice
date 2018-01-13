defmodule Alice.EventProcessor do
  alias Lace.Redis
  require Logger

  defmacro is_cache(type) do
    quote do
      unquote(type) in [
          # Guild
          "GUILD_CREATE", "GUILD_UPDATE", "GUILD_DELETE", 
          # Channels
          "CHANNEL_CREATE", "CHANNEL_UPDATE", "CHANNEL_DELETE",
          # Emotes
          "GUILD_EMOJIS_UPDATE", 
          # Members
          "GUILD_MEMBER_ADD", "GUILD_MEMBER_REMOVE", "GUILD_MEMBER_UPDATE", 
          "GUILD_MEMBERS_CHUNK", 
          # Roles
          "GUILD_ROLE_CREATE", "GUILD_ROLE_UPDATE", "GUILD_ROLE_DELETE", 
          # User
          "PRESENCE_UPDATE", "USER_UPDATE", "VOICE_STATE_UPDATE"
        ]
    end
  end

  def process do
    spawn fn -> get_event() end
    # Don't abuse redis too much
    # Artificially limit us to 1000/s throughput
    Process.sleep 1
    process()
  end

  defp get_event do
    {:ok, data} = Redis.q ["LPOP", System.get_env("EVENT_QUEUE")]
    unless data == :undefined do
      # %{"t" => type, "d" => data}
      event = data |> Poison.decode!
      try do
        process_event event["t"], event["d"]
      rescue
        e -> Sentry.capture_exception e, [stacktrace: System.stacktrace()]
      end
    end
  end

  defp process_event(type, data) when type == "MESSAGE_CREATE" do
    Alice.Command.process_message data
  end

  defp process_event(type, data) when is_cache(type) do
    Logger.debug "Got cache event: #{inspect type} with data #{inspect data}"
    Redis.q ["RPUSH", System.get_env("CACHE_QUEUE"), Poison.encode!(%{"t" => type, "d" => data})]
  end

  defp process_event(type, data) do
    #Logger.info "Got unknown event: #{inspect event}!"
  end
end
