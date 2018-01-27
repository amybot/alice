defmodule Alice.Cmd.Levels do
  use Annotatable, [:command]
  import Emily.Embed
  import Alice.Util
  alias Lace.Redis
  require Logger

  @command %{name: "rank", desc: "command.desc.levels.rank"}
  def rank(_name, args, _argstr, ctx) do
    # TODO: Make this not no-op. Blocking on per-guild levels being finished
  end

  @command %{name: "profile", desc: "command.desc.levels.profile"}
  def profile(_name, args, _argstr, ctx) do
    ;
  end
end