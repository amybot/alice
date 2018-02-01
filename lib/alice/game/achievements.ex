defmodule Alice.Achievements do
  @moduledoc """
  Because I like trying to get people addicted :D
  """

  alias Alice.Database
  alias Alice.Achievement

  require Logger

  defmodule Event do
    defstruct [
      # Type of the event.
      :t,
      # Event data. 
      :d,
      # Player who got the achievement
      :player,
    ]

    @type t :: %Event{t: binary, d: map, player: map}
  end

  defmodule Achievement do
    defstruct [
      # ID, used for internal handling / assignment / etc.
      # Do note that you can't use the `.` character in ids because I was 
      # really lazy with DB handling
      # :tada:
      :id,
      # Name (non-localized?)
      :name, 
      # Description (non-localized)
      :desc, 
      # Used for display because I'm too lazy to make my own art
      :emote,
      # Requirements for the achievement. Should be a function that takes in 
      # an event and outputs a boolean. The first arg. is the event, and the 
      # second arg. is any contextual data (ex. a MESSAGE_CREATE ctx).
      :requirements,
    ]

    @type t :: %Achievement{name: binary, desc: binary, emote: binary, requirements: ((map, map) -> boolean)}
  end

  # This is such a fucking stupid way to handle not being able to stuff anon.
  # functions into module attributes...
  def achievements do
    %{
      guild_levels: [
        %Achievement{
          id: "level-1",
          name: "level 1",
          desc: "reach level 1",
          emote: ":fire:",
          requirements: fn(event, _ctx) -> 
              d = event["d"]
              level = d["level"]
              level >= 1
            end
        },
      ]
    }
  end

  # I hate writing typespecs, so I get lazy and enforce with guards :D
  #
  # plz save me :sob:
  def handle_event(event, ctx) when is_map(event) and is_map(ctx) do
    t = event["t"]
    _d = event["d"]
    player = event["player"]
    case t do
      "GUILD_LEVEL_UP" -> 
        # Try to get the ach. for that level
        achievements()[:guild_levels]
        # Check that this event matches the requirements
        |> Enum.filter(fn(x) -> x.requirements.(event, ctx) end)
        # Check if the player already has it
        |> Enum.filter(fn(x) -> !Database.has_achievement?(player, x.id) end)
        # Apply
        |> Enum.each(fn(x) -> 
            Database.set_achievement player, x.id, true
            # TODO: Send a message to the player or something I guess
            Logger.info "#{inspect player, pretty: true} just got achievement #{inspect x, pretty: true}"
          end)
        
      "GLOBAL_LEVEL_UP" -> nil
      _ ->
        Logger.debug "[ACH] Got unknown event type: #{inspect t}"
    end
  end
end