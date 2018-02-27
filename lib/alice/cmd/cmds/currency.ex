defmodule Alice.Cmd.Currency do
  use Annotatable, [:command]
  use Timex

  import Emily.Embed
  import Alice.Util
  alias Lace.Redis
  alias Alice.Cache
  require Logger

  # TODO: Set up anti-cheating stuff in here eventually

  @daily_amount 100
  @daily_bonus 10

  @day_s 86400

  @symbol ":white_flower:"

  @command %{name: "balance", desc: "command.desc.currency.balance"}
  def balance(_name, _args, _argstr, ctx) do
    lang = ctx["channel_id"] |> Alice.Cache.channel_to_guild_id 
                             |> Alice.Database.get_language
    bal = Alice.Database.balance ctx["author"]
    res = Alice.I18n.translate(lang, "command.currency.balance")
          |> String.replace("$balance", "#{inspect bal}")
          |> String.replace("$symbol", @symbol)
    ctx
    |> ctx_embed
    |> title("Balance")
    |> desc(res)
    |> Emily.create_message(ctx["channel_id"])
  end

  @command %{name: "baltop", desc: "command.desc.currency.baltop"}
  def baltop(_name, _args, _argstr, ctx) do
    balance_str = Alice.Database.balance_top
                  |> Enum.reduce("", fn(x, acc) -> 
                        du = x["id"] |> Cache.get_user 
                        acc <> "#{du["username"]}##{du["discriminator"]}: #{x["balance"]}" <> @symbol <> "\n"
                      end)
    ctx
    |> ctx_embed
    |> title("Top balances")
    |> desc("#{balance_str}")
    |> Emily.create_message(ctx["channel_id"])
  end

  @command %{name: "daily", desc: "command.desc.currency.daily"}
  def daily(_name, _args, _argstr, ctx) do
    user = ctx["author"]
    lang = ctx["channel_id"] |> Alice.Cache.channel_to_guild_id 
                             |> Alice.Database.get_language
    last_time = Alice.Database.get_last_daily user
    last_time = unless is_nil last_time do
                  {:ok, time} = Timex.parse(last_time, "{ISO:Extended}")
                  time
                else
                  Timex.epoch() |> Timex.to_datetime
                end
    now = now()
    then = tomorrow()
    diff = Timex.diff now, last_time, :days

    if diff >= 1 do #or Timex.day(now) - Timex.day(last_time) == 1 do
      # Get streak
      streak = Alice.Database.get_currency_daily_streak user
      # Check for reset or nah
      streak = if diff > 1 and not (streak == 0) do
                Alice.Database.set_currency_daily_streak user, 0
                0
              else
                Alice.Database.incr_currency_daily_streak user
                streak + 1
              end
      streak_reset = streak == 0

      bonus_amount = if streak_reset do
                        0
                      else
                        @daily_bonus * streak
                      end

      final_amount = @daily_amount + bonus_amount
      _new_user = Alice.Database.increment_balance user, final_amount
      #Redis.q ["SET", "user:#{user["id"]}:daily-cooldown", now]
      Alice.Database.set_last_daily user, Timex.format!(now, "{ISO:Extended}")
      res = Alice.I18n.translate(lang, "command.currency.daily.success")
            |> String.replace("$amount", "#{inspect @daily_amount}")
            |> String.replace("$symbol", @symbol)
      streak_msg = if streak_reset do
                    Alice.I18n.translate(lang, "command.currency.daily.streak.reset")
                    |> String.replace("$symbol", @symbol)
                  else
                    Alice.I18n.translate(lang, "command.currency.daily.streak.streak")
                    |> String.replace("$amount", "#{bonus_amount}")
                    |> String.replace("$symbol", @symbol)
                    |> String.replace("$streak", "#{streak}")
                  end
      ctx
      |> ctx_embed
      |> title("Daily")
      |> desc(res <> "\n" <> streak_msg)
      |> Emily.create_message(ctx["channel_id"])
    else
      #time_left = (last_time + @day_s) - now
      #duration = Duration.from_seconds time_left
      duration = Timex.diff then, Timex.now(), :seconds
      res = Alice.I18n.translate(lang, "command.currency.daily.failure")
            |> String.replace("$time", "#{Duration.from_seconds(duration) |> Timex.format_duration(:humanized)}")
      Emily.n_create_message ctx["channel_id"], [content: nil, embed: error(ctx, res)]
    end
  end

  @command %{name: "pay", desc: "command.desc.currency.pay"}
  def pay(name, args, _argstr, ctx) do
    lang = ctx["channel_id"] |> Alice.Cache.channel_to_guild_id 
                             |> Alice.Database.get_language
    if length(args) < 2 do
      Emily.n_create_message ctx["channel_id"], [content: nil, 
          embed: error(ctx, Alice.I18n.missing_arg(lang, name, "target, amount"))]
    else
      mentions = ctx["mentions"]
      if length(mentions) == 0 do
        # TODO: Is this actually a good error for this? 
        Emily.n_create_message ctx["channel_id"], [content: nil, 
          embed: error(ctx, Alice.I18n.missing_arg(lang, name, "target, amount"))]
      else
        # amy!pay <target> <amount>
        send_balance = Alice.Database.balance ctx["author"]
        #target = Enum.at args, 0
        amount = Enum.at args, 1
        try do
          final_amount = amount |> String.to_integer
          target = hd mentions
          if send_balance >= final_amount do
            # Transfer
            Alice.Database.increment_balance ctx["author"], -amount
            Alice.Database.increment_balance target, amount
            res = Alice.I18n.translate(lang, "command.currency.pay.success")
                  |> String.replace("$amount", amount)
                  |> String.replace("$target", target["username"])
            ctx
            |> ctx_embed
            |> title("Pay")
            |> desc(res)
            |> Emily.create_message(ctx["channel_id"])
          else
            error_msg = Alice.I18n.translate(lang, "command.currency.pay.failure-too-poor")
            Emily.n_create_message ctx["channel_id"], [content: nil, embed: error(ctx, error_msg)]
          end
        rescue
          _ -> 
            # Probably not an integer, error out
            error_msg = Alice.I18n.translate(lang, "command.currency.pay.failure-bad-amount")
                        |> String.replace("$amount", amount)
            Emily.n_create_message ctx["channel_id"], [content: nil, embed: error(ctx, error_msg)]
        end
      end
    end
  end
end