defmodule Alice.Music do
  import Emily.Embed
  import Alice.Util
  use Timex
  require Logger

  @moduledoc """
  Handles audio track events
  """

  #def process_event("AUDIO_TRACK_START", data) do
  #  embed()
  #  |> field("Hotspring response", """
  #          ```Elixir
  #          #{inspect data, pretty: true}
  #          ```
  #          """, false)
  #  |> color(0xFF69B4)
  #  |> Emily.create_message(data["channel"])
  #end

  # TODO: I18n

  def process_event("AUDIO_TRACK_START", data) do
    info = data["info"]
    length = Duration.from_milliseconds info["length"]
    data
    |> track_event_embed
    |> title("Song started")
    |> url(info["uri"])
    |> field("Title", info["title"], true)
    |> field("Artist", info["author"], true)
    |> field("Length", "#{Timex.format_duration length, :humanized}", true)
    |> Emily.create_message(data["ctx"]["channel"] |> String.to_integer)
  end

  def process_event("AUDIO_TRACK_STOP", _data) do
    #
  end

  def process_event("AUDIO_TRACK_PAUSE", _data) do
    # TODO
  end

  def process_event("AUDIO_TRACK_QUEUE", data) do
    info = data["info"]
    is_many = is_nil(info["author"]) and is_nil(info["identifier"]) 
                  and is_nil(info["uri"])
    if is_many do
      data
      |> track_event_embed
      |> title(Alice.I18n.translate("en", "command.music.queue.success"))
      |> field("", "Queued #{info["length"]} songs.", false)
      |> Emily.create_message(data["ctx"]["channel"] |> String.to_integer)
    else
      length = Duration.from_milliseconds info["length"]
      data
      |> track_event_embed
      |> title(Alice.I18n.translate("en", "command.music.queue.success"))
      |> url(info["uri"])
      |> field("Title", info["title"], true)
      |> field("Artist", info["author"], true)
      |> field("Length", "#{Timex.format_duration length, :humanized}", true)
      |> Emily.create_message(data["ctx"]["channel"] |> String.to_integer)
    end
  end

  def process_event("AUDIO_TRACK_INVALID", data) do
    try do
      data
      |> track_event_embed
      |> color(0xFF0000)
      |> title("Error!")
      |> desc("Invalid audio track!")
      |> Emily.create_message(data["ctx"]["channel"] |> String.to_integer)
    rescue
      e -> Logger.info "ERROR - #{inspect e, pretty: true}"
    end
  end

  def process_event("AUDIO_QUEUE_END", _data) do
    #
  end

  def process_event(type, data) do
    Logger.debug "Got unhandled audio event: #{type} with data: #{inspect data}"
  end
end