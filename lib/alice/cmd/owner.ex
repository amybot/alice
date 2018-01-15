defmodule Alice.Cmd.Owner do
  use Annotatable, [:command]
  import Emily.Embed
  require Logger

  @command %{name: "test", desc: "command.desc.owner.test", owner: true}
  def test(_name, args, _argstr, ctx) do
    if ctx["author"]["id"] == 128316294742147072 do
      embed = embed()
              |> title("test embed!")
              |> desc("this is a test")
              |> url("https://google.com/")
              |> color(0xFF69B4)
              |> thumbnail("https://i.imgur.com/ktCb1Ff.jpg")
              |> field("1", "1", true)
              |> field(true)
              |> field("2", "2", true)
      Emily.create_message ctx["channel_id"], [content: "Args: #{inspect args}", embed: embed]
    end
  end

  @command %{name: "eval", desc: "command.desc.owner.eval", owner: true}
  def eval(_name, _args, argstr, ctx) do
    if ctx["author"]["id"] == 128316294742147072 do
      try do
        {result, _} = argstr
                      |> String.replace("BOT_TOKEN", "NOT_BOT_TOKEN")
                      |> Code.eval_string([ctx: ctx])
                         
        Emily.create_message ctx["channel_id"], """
                                                Output: 
                                                ```Elixir
                                                #{inspect(result) |> String.replace(System.get_env("BOT_TOKEN"), "Nice try :)") }
                                                ```
                                                """
      rescue
        e -> 
          Emily.create_message ctx["channel_id"], """
                                                  Exception while processing: 
                                                  ```Elixir
                                                  #{Exception.format(:error, e) }
                                                  ```
                                                  """
      end
    end
  end
end