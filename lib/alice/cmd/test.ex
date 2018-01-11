defmodule Alice.Cmd.Test do
  @behaviour Alice.Cmd

  def command("test", args, _argstr, ctx) do
    Emily.create_message ctx["channel_id"], "Args: #{inspect args}"
  end

  def command("eval", _args, argstr, ctx) do
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