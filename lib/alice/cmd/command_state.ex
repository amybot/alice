defmodule Alice.CommandState do
  use Agent
  require Logger

  def start_link do
    Logger.info "[CMD] Starting command state agent..."
    Agent.start_link(fn -> %{} end, name: CommandState)
  end

  def get_command(cmd) do
    Agent.get(CommandState, fn state -> state[cmd] end)
  end

  defp get_annotations(mod) do
    apply mod, :annotations, []
  end

  def add_commands(mod) do #, annotations) do
    annotations = get_annotations mod
    functions = Map.keys annotations

    for f <- functions do
      list = annotations[f]
      for a <- list do
        if a[:annotation] == :command do
          # This is our command data. See command.ex
          val = a[:value]
          # Construct the final data
          if is_list val do
            for v <- val do
              update_cmd mod, f, v
            end
          else
            update_cmd mod, f, val
          end
        end
      end
    end
  end

  defp update_cmd(mod, f, val) do
    data = %{
      name: String.downcase(val[:name]),
      desc: val[:desc],
      invoke: fn(name, args, argstr, ctx) -> 
          apply mod, f, [name, args, argstr, ctx]
        end,
      owner: val[:owner] || false
    }
    Agent.update(CommandState, fn state -> 
        Logger.debug "[CMD] Mapping command #{inspect val[:name]} -> #{inspect mod}.#{Atom.to_string(f)}/4"
        Map.put state, val[:name], data
      end)
  end
end