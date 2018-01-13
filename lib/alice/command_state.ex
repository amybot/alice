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

  def add_commands(mod, annotations) do
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
    name: val[:name],
    desc: val[:desc],
    invoke: fn(name, args, argstr, ctx) -> 
        apply mod, f, [name, args, argstr, ctx]
      end
    }
    Agent.update(CommandState, fn state -> 
        Logger.info "[CMD] Mapping command #{inspect val[:name]} -> #{inspect mod}.#{inspect Atom.to_string(f)}/4"
        Map.put state, val[:name], data
      end)
  end
end