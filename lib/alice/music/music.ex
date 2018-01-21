defmodule Alice.Music do
  import Emily.Embed
  require Logger

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

  def process_event(type, data) do
    Logger.info "Got audio event: #{type} with data: #{inspect data}"
    embed()
    |> field("Hotspring response", """
            ```Elixir
            #{inspect data, pretty: true}
            ```
            """, false)
    |> color(0xFF69B4)
    |> Emily.create_message(data["channel"])
  end
end