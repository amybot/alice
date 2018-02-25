defmodule Alice.Cmd.Owner do
  use Annotatable, [:command]
  import Emily.Embed
  require Logger

  @command %{name: "test", desc: "command.desc.owner.test", owner: true}
  def test(_name, _args, _argstr, ctx) do
    if ctx["author"]["id"] == "128316294742147072" do
      embed()
      |> title("test embed!")
      |> desc("this is a test")
      |> url("https://google.com/")
      |> color(0xFF69B4)
      |> thumbnail("https://i.imgur.com/ktCb1Ff.jpg")
      |> field("1", "1", true)
      |> field(true)
      |> field("2", "2", true)
      |> Emily.create_message(ctx["channel_id"])
    end
  end

  @command %{name: "sk", desc: "command.desc.owner.sk", owner: true}
  def sketchify(_name, _args, argstr, ctx) do
    if ctx["author"]["id"] == "128316294742147072" do
      res = HTTPoison.post!("https://verylegit.link/sketchify", "long_url=" <> argstr, [{"content-type", "application/x-www-form-urlencoded; charset=UTF-8"}]).body
      embed()
      |> title("Pretty sketchy amirite")
      |> desc("""
              https://#{res}
              """)
      |> color(0xFF69B4)
      |> Emily.create_message(ctx["channel_id"])
    end
  end

  @command %{name: "stats", desc: "command.desc.owner.stats", owner: true}
  def info(_name, _args, _argstr, ctx) do
    if ctx["author"]["id"] == "128316294742147072" do
      otp     = :erlang.system_info :otp_release
      machine = :erlang.system_info :machine
      process = :erlang.system_info :process_count
      version = :erlang.system_info :version
      arch    = :erlang.system_info :system_architecture
      embed()
      |> title("stats!!")
      |> desc("""
              Erlang/OTP #{otp} erts-#{inspect version} #{inspect machine}
              Running #{inspect process} PIDs on #{inspect arch}
              """)
      |> color(0xFF69B4)
      |> Emily.create_message(ctx["channel_id"])
    end
  end

  @command %{name: "testvoice", desc: "command.desc.owner.testvoice", owner: true}
  def test_voice(_name, _args, _argstr, ctx) do
    if ctx["author"]["id"] == "128316294742147072" do
      guild = "206584013790380033"
      channel = "206584013790380034"
      embed()
      |> title("Attempting voice join")
      |> desc("guild: #{guild}\nchannel: #{channel}")
      |> color(0xFF69B4)
      |> Emily.create_message(ctx["channel_id"])
      voice_data = HTTPoison.get! System.get_env("SHARD_API") <> "/voice/#{guild}/#{channel}/connect", [], [timeout: 60_000, recv_timeout: 60_000]
      hotspring_res = HTTPoison.post! System.get_env("HOTSPRING_API") <> "/connection/open", voice_data.body, [{"Content-Type", "application/json"}]
      decoded_hs_res = Poison.decode!(hotspring_res.body)
      embed()
      |> title("Hotspring response")
      |> desc("""
              ```Elixir
              #{inspect decoded_hs_res, pretty: true}
              ```
              """)
      |> color(0xFF69B4)
      |> Emily.create_message(ctx["channel_id"])
    end
  end

  @command %{name: "eval", desc: "command.desc.owner.eval", owner: true}
  def eval(_name, _args, argstr, ctx) do
    if ctx["author"]["id"] == "128316294742147072" do
      try do
        {result, _} = argstr
                      |> String.replace("BOT_TOKEN", "NOT_BOT_TOKEN")
                      |> Code.eval_string([ctx: ctx])
                         
        Emily.n_create_message ctx["channel_id"], """
                                                Output: 
                                                ```Elixir
                                                #{inspect(result) |> String.replace(System.get_env("BOT_TOKEN"), "Nice try :)") }
                                                ```
                                                """
      rescue
        e -> 
          Logger.warn "#{Exception.format(:error, e)}"
          Emily.n_create_message ctx["channel_id"], """
                                                  Exception while processing: 
                                                  ```Elixir
                                                  #{Exception.format(:error, e) }
                                                  ```
                                                  """
      end
    end
  end

  @command %{name: "shell", desc: "command.desc.owner.shell", owner: true}
  def shell(_name, args, _argstr, ctx) do
    if ctx["author"]["id"] == "128316294742147072" do
      try do
        cmd = hd args
        arg = tl args
        {result, code} = System.cmd cmd, arg
                         
        Emily.n_create_message ctx["channel_id"], """
                                                Output: 
                                                ```
                                                #{result |> String.replace(System.get_env("BOT_TOKEN"), "Nice try :)") }
                                                Command exited with code #{inspect code}
                                                ```
                                                """
      rescue
        e -> 
          Emily.n_create_message ctx["channel_id"], """
                                                  Exception while processing: 
                                                  ```Elixir
                                                  #{Exception.format(:error, e) }
                                                  ```
                                                  """
      end
    end
  end
end