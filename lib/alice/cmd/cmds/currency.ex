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
    embed = ctx
            |> ctx_embed
            |> title("Balance")
            |> desc(res)
    Emily.create_message ctx["channel_id"], [content: nil, embed: embed]
  end

  @command %{name: "baltop", desc: "command.desc.currency.baltop"}
  def baltop(_name, _args, _argstr, ctx) do
    balance_str = Alice.Database.balance_top
                  |> Enum.reduce("", fn(x, acc) -> 
                        discord_entity = x["id"] |> Cache.get_user 
                        # TODO: This is gross
                        acc <> "#{discord_entity["username"]}##{discord_entity["discriminator"]}: #{inspect x["balance"]}" <> @symbol <> "\n"
                      end)
    embed = ctx
            |> ctx_embed
            |> title("Top balances")
            |> desc("#{balance_str}")
    Emily.create_message ctx["channel_id"], [content: nil, embed: embed]
  end

  @command %{name: "daily", desc: "command.desc.currency.daily"}
  def daily(_name, _args, _argstr, ctx) do
    user = ctx["author"]
    lang = ctx["channel_id"] |> Alice.Cache.channel_to_guild_id 
                             |> Alice.Database.get_language
    {:ok, last_time} = Redis.q ["GET", "user:#{user["id"]}:daily-cooldown"]
    last_time = unless last_time == :undefined do
                  last_time |> String.to_integer
                else
                  0
                end

    now = now_s()
    cooldown = now - last_time

    if cooldown >= @day_s do
      _new_user = Alice.Database.increment_balance user, @daily_amount
      Redis.q ["SET", "user:#{user["id"]}:daily-cooldown", now]
      res = Alice.I18n.translate(lang, "command.currency.daily.success")
            |> String.replace("$amount", "#{inspect @daily_amount}")
            |> String.replace("$symbol", @symbol)
      embed = ctx
              |> ctx_embed
              |> title("Daily")
              |> desc(res)
      Emily.create_message ctx["channel_id"], [content: nil, embed: embed]
    else
      time_left = (last_time + @day_s) - now
      duration = Duration.from_seconds time_left
      res = Alice.I18n.translate(lang, "command.currency.daily.failure")
            |> String.replace("$time", "#{Timex.format_duration duration, :humanized}")
      Emily.create_message ctx["channel_id"], [content: nil, embed: error(ctx, res)]
    end
  end

  @command %{name: "pay", desc: "command.desc.currency.pay"}
  def pay(name, args, _argstr, ctx) do
    lang = ctx["channel_id"] |> Alice.Cache.channel_to_guild_id 
                             |> Alice.Database.get_language
    if length(args) < 2 do
      Emily.create_message ctx["channel_id"], [content: nil, 
          embed: error(ctx, Alice.I18n.missing_arg(lang, name, "target, amount"))]
    else
      mentions = ctx["mentions"]
      if length(mentions) == 0 do
        # TODO: Is this actually a good error for this? 
        Emily.create_message ctx["channel_id"], [content: nil, 
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
            Emily.create_message ctx["channel_id"], [content: nil, embed: error(ctx, error_msg)]
          end
        rescue
          _ -> 
            # Probably not an integer, error out
            error_msg = Alice.I18n.translate(lang, "command.currency.pay.failure-bad-amount")
                        |> String.replace("$amount", amount)
            Emily.create_message ctx["channel_id"], [content: nil, embed: error(ctx, error_msg)]
        end
      end
    end
  end
end