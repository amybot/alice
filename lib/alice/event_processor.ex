defmodule Alice.EventProcessor do
  alias Lace.Redis
  require Logger

  use GenServer

  ##########
  # Macros #
  ##########

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

  defmacro is_audio(type) do
    quote do
      unquote(type) in [
          # Track
          "AUDIO_TRACK_START", "AUDIO_TRACK_STOP", "AUDIO_TRACK_PAUSE", 
          "AUDIO_TRACK_QUEUE"
        ]
    end
  end

  #################
  # GenServer API #
  #################

  def start_link(opts) do
    GenServer.start_link __MODULE__, opts, name: __MODULE__
  end

  def init(opts) do
    #{:ok, subscription} = Gnat.sub :gnat, self(), "event-queue", [queue_group: "event-queue"]

    state = %{
      subscription: nil,
    }

    {:ok, state}
  end

  def handle_info(:setup, state) do
    # For some fucking reason, gnat is retarded and won't actually 
    # register a name for itself, it seems? x-x
    # This forcibly registers it to :gnat to work around this
    # queer behaviour.
    {:ok, subscription} = Gnat.sub :gnat, self(), "event-queue", [queue_group: "event-queue"]
    Logger.info "[EVENT] Subscribed to NATS"
    {:noreply, %{state | subscription: subscription}}
  end

  def handle_info({:find_nats, sup}, state) do
    loc = Process.whereis :gnat
    if is_nil loc do
      Logger.warn "[EVENT] We lost nats! Let's find it again..."
      Process.sleep 1000
      if Enum.member? Process.registered(), :gnat do
        Logger.warn "[EVENT] Cleaning up old nats registry..."
        Process.unregister :gnat
      end
      for {name, pid, _, _} <- Supervisor.which_children(sup) do
        if name == Gnat do
          Process.register pid, :gnat
          Logger.warn "[EVENT] We found nats! Woo!"
        end
      end
      Process.send_after self(), :setup, 100
    end
    Process.send_after self(), {:find_nats, sup}, 100
    {:noreply, state}
  end

  def handle_info({:msg, %{body: body, topic: topic, reply_to: reply_to} = content}, state) do
    #Logger.info "Got message: #{inspect body, pretty: true}"
    event = body |> Poison.decode!
    spawn fn -> 
        try do
          process_event event["t"], event["d"]
        rescue
          e -> Sentry.capture_exception e, [stacktrace: System.stacktrace()]
        end
      end
    {:noreply, state}
  end

  def handle_info(unknown_message, state) do
    Logger.info "Unknown message: #{inspect unknown_message, pretty: true}"
    {:noreply, state}
  end

  ######################
  # Internal functions #
  ######################

  #def process do
  #  spawn fn -> get_event() end
  #  # Don't abuse redis too much
  #  # Artificially limit us to 100/s throughput
  #  Process.sleep 10
  #  process()
  #end

  #defp get_event do
  #  {:ok, data} = Redis.q ["LPOP", System.get_env("EVENT_QUEUE")]
  #  unless data == :undefined do
  #    # %{"t" => type, "d" => data}
  #    event = data |> Poison.decode!
  #    try do
  #      process_event event["t"], event["d"]
  #    rescue
  #      e -> Sentry.capture_exception e, [stacktrace: System.stacktrace()]
  #    end
  #  end
  #end

  defp process_event(type, data) when type == "MESSAGE_CREATE" do
    # TODO: Pre-process this (make it swap in strings for integers so that operations are consistent)
    Alice.Command.process_message data
  end

  defp process_event(type, data) when is_cache(type) do
    Logger.debug "Got cache event: #{inspect type} with data #{inspect data}"
    # Note: In the original cache service, this was wrapped in try/rescue to 
    #       let Sentry do its thing. With it here, this is covered in 
    #       get_event/0 so we don't need to worry about it here
    Alice.Cache.process_event %{"t" => type, "d" => data}
  end

  defp process_event(type, data) when is_audio(type) do
    Logger.debug "Got audio event: #{inspect type} with data #{inspect data}"
    Alice.Music.process_event type, data
  end

  defp process_event(type, data) do
    Logger.debug "Got unknown event: #{inspect type} with data #{inspect data}"
  end
end
