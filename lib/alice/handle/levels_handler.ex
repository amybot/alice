defmodule Alice.LevelsHandler do
  alias Lace.Redis
  require Logger

  def process_message(ctx) do
    # Get guild id
    # TODO: This may end up being very expensive...
    guild_id = Alice.Cache.channel_to_guild_id ctx["channel_id"]

    # Global chat levels
    unless is_ratelimited?(ctx["author"]) do
      xp = get_next_xp()
      Alice.Database.increment_xp ctx["author"], xp
    end
    # Per-guild chat levels
    unless is_guild_ratelimited(ctx["author"], guild_id) do
      xp = get_next_xp()
      #Alice.Database.
      # TODO: Make this not no-op
    end
  end

  defp is_guild_ratelimited?(user, guild_id) when is_map(user) and is_integer(guild_id) do
    # 1 xp gain / minute
    case Hammer.check_rate("chat-xp-ratelimit:#{inspect guild_id}:#{inspect user["id"]}", 60000, 1) do # lol
      {:allow, _count} ->
        Logger.debug "Giving xp to #{inspect user, pretty: true} due to not hitting guild-level ratelimit 'chat-xp-ratelimit:#{inspect guild_id}'."
        false
      {:deny, _count} ->
        Logger.debug "Denying xp to #{inspect user, pretty: true} due to hitting guild-level ratelimit 'chat-xp-ratelimit:#{inspect guild_id}'."
        true
    end
  end

  defp is_ratelimited?(user) when is_map(user) do
    # 1 xp gain / minute
    case Hammer.check_rate("chat-xp-ratelimit:#{inspect user["id"]}", 60000, 1) do # lol
      {:allow, _count} ->
        Logger.debug "Giving xp to #{inspect user, pretty: true} due to not hitting global ratelimit 'chat-xp-ratelimit'."
        false
      {:deny, _count} ->
        Logger.debug "Denying xp to #{inspect user, pretty: true} due to hitting global ratelimit 'chat-xp-ratelimit'."
        true
    end
  end

  # Generates some xp E [10, 20]
  defp get_next_xp do
    # :rand.uniform(int) generates a value x E [1, N)
    rand = :rand.uniform(12)
    9 + rand
  end
end