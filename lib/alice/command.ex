defmodule Alice.Command do
  @moduledoc """
  When creating commands, you should annotate them with `@command data`. 
  Command data is of the form:

  ```Elixir
  %{
    # Command names may not have whitespace, EVER.
    name: "command_name",
    # A short description of the command
    desc: "a command that does things. and also stuff",
  }
  ```
  You may also pass a list of mappings, if you want many commands on one 
  function.
  """

  require Logger

  @prefix "amy@"

  def process_message(ctx) do
    msg = ctx["content"]

    # TODO: Remove this, testing-only~
    if ctx["author"]["id"] == 128316294742147072 do
      words = String.split msg, ~R/\s+/, [parts: 2, trim: true]
      cmd = words |> List.first
      unless is_nil cmd do
        if String.starts_with?(cmd, @prefix) do
          cmd_name = cmd |> String.slice(String.length(@prefix)..2048)
          argstr = if length(words) > 1 do
            words |> List.last
          else
            ""
          end
          args = if length(words) > 1 do
            words |> List.last |> String.split(~R/\s+/, [trim: true])
          else
            []
          end

          match = Alice.CommandState.get_command cmd_name
          unless is_nil match do
            invoke = match[:invoke]
            unless is_nil invoke do
              invoke.(cmd_name, args, argstr, ctx)
            else
              Logger.warn "Caught nil invoke for #{cmd_name}!"
            end
          end

          #command(cmd_name, args, argstr, ctx)
        end
      end
    end
  end
end