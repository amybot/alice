defmodule Alice.Cmd.Currency do
  use Annotatable, [:command]
  use Timex

  import Emily.Embed
  import Alice.Util
  alias Lace.Redis
  alias Alice.Cache
  require Logger

  @daily_amount 100
  @day_s 86400

  @command %{name: "balance", desc: "command.desc.currency.balance"}
  def balance(_name, _args, _argstr, ctx) do
    bal = Alice.ReadRepo.balance ctx["author"]
    res = Alice.I18n.translate("en", "command.currency.balance")
          |> String.replace("$balance", "#{inspect bal}")
    embed = ctx
            |> ctx_embed
            |> title("Balance")
            |> desc(res)
    Emily.create_message ctx["channel_id"], [content: nil, embed: embed]
  end

  @command %{name: "baltop", desc: "command.desc.currency.baltop"}
  def baltop(_name, _args, _argstr, ctx) do
    balance_str = Alice.ReadRepo.balance_top
                  |> Enum.reduce("", fn(x, acc) -> 
                        discord_entity = x.user_id |> Decimal.to_string |> Cache.get_user 
                        # TODO: This is gross
                        acc <> "#{discord_entity["username"]}##{discord_entity["discriminator"]}: #{inspect x.balance}:white_flower:\n"
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
    {:ok, last_time} = Redis.q ["GET", "user:#{user["id"]}:daily-cooldown"]
    last_time = unless last_time == :undefined do
                  last_time |> String.to_integer
                else
                  0
                end

    now = now_s()
    cooldown = now - last_time

    if cooldown >= @day_s do
      _new_user = Alice.WriteRepo.increment_balance user, @daily_amount
      Redis.q ["SET", "user:#{user["id"]}:daily-cooldown", now]
      res = Alice.I18n.translate("en", "command.currency.daily.success")
            |> String.replace("$amount", "#{inspect @daily_amount}")
      embed = ctx
              |> ctx_embed
              |> title("Daily")
              |> desc(res)
      Emily.create_message ctx["channel_id"], [content: nil, embed: embed]
    else
      time_left = (last_time + @day_s) - now
      duration = Duration.from_seconds time_left
      res = Alice.I18n.translate("en", "command.currency.daily.failure")
            |> String.replace("$time", "#{Timex.format_duration duration, :humanized}")
      Emily.create_message ctx["channel_id"], [content: nil, embed: error(ctx, res)]
    end
  end
end