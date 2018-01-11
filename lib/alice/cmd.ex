defmodule Alice.Cmd do
  @callback command(name :: String.t, args :: list(String.t), argstr :: String.t, ctx :: term) :: any()

  def command(_name, _args, _ctx) do
    # no-op
  end
end