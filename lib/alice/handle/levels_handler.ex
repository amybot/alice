defmodule Alice.LevelsHandler do
  alias Lace.Redis
  require Logger

  def process_message(ctx) do
    # Get guild id
    guild_id = Alice.Cache.channel_to_guild_id ctx["channel_id"]
    Logger.debug "[LVL] Found guild: #{inspect guild_id}"

    # Global chat levels
    Logger.debug "[LVL] Handling global levels"
    unless is_ratelimited?(ctx["author"]) do
      try do
        xp = get_next_xp()
        Alice.Database.increment_xp ctx["author"], xp
        # TODO: Handle achievement here
        Logger.debug "[LVL] Globals handled!"
      rescue
        e -> Logger.warn "#{inspect e, pretty: true} - #{inspect System.stacktrace(), pretty: true}"
      end
    else
      Logger.debug "[LVL] User ratelimited on global levels"
    end
    Logger.debug "[LVL] Handling guild levels"
    # Per-guild chat levels
    unless is_guild_ratelimited?(ctx["author"], guild_id) do
      Logger.debug "[LVL] #{inspect ctx["author"]["id"]} not ratelimited on #{inspect guild_id} levels"
      try do
        prev = Alice.Database.get_guild_xp ctx["author"], guild_id
        Logger.debug "[LVL] Prev: #{inspect prev}"
        xp = get_next_xp()
        Logger.debug "[LVL] XP: #{inspect xp}"
        Logger.debug "[LVL] Next: #{inspect (prev + xp)}"
        Alice.Database.increment_guild_xp ctx["author"], guild_id, xp
        Logger.debug "[LVL] Incremented in DB"
        if is_level_up?(prev, prev + xp) do
          Logger.debug "Level up! #{inspect ctx["author"], pretty: true}"
        end
        Logger.debug "[LVL] Guilds handled!"
      rescue
        e -> Logger.warn "#{inspect e, pretty: true} - #{inspect System.stacktrace(), pretty: true}"
      end
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

  #####################
  # Utility functions #
  #####################

  def is_level_up?(old, new) do
    xp_to_level(old) < xp_to_level(new)
  end

  def level_to_xp(level) when is_integer(level) do
    max 0, (100 * level) + (20 * (level - 1))
  end

  def xp_to_level(xp) when is_integer(xp) do
    if xp < level_to_xp(1) do
      0
    else
      max 0, r_xp_to_level(xp, 0)
    end
  end

  defp r_xp_to_level(xp, level) when is_integer(xp) and is_integer(level) do
    if xp < level_to_xp(level) do
      level - 1
    else
      r_xp_to_level xp - level_to_xp(level), level + 1
    end
  end

  def full_level_to_xp(level) when is_integer(level) do
    r_full_level_to_xp level, 0
  end

  defp r_full_level_to_xp(level, xp) do
    if level < 0 do
      xp
    else
      r_full_level_to_xp level - 1, xp + level_to_xp(level)
    end
  end

  # Generates some xp E [10, 20]
  defp get_next_xp do
    # :rand.uniform(int) generates a value x E [1, N)
    rand = :rand.uniform(11)
    9 + rand
  end
end