defmodule Alice.I18n do
  use GenServer
  require Logger

  @dir :code.priv_dir :alice

  @unknown_translation "<unknown translation>"

  def start_link(_) do
    GenServer.start_link __MODULE__, [], name: __MODULE__
  end

  def init([]) do
    files = File.ls!(get_path("/lang/"))
    Logger.info "[I18N] #{inspect length(files)} translation file(s) available"

    lang = files |> Enum.reduce(%{}, fn(file, l) -> 
        split = String.split(file, ".", parts: 2)
        locale = List.first(split)
        if List.last(split) == "yaml" do
          Logger.info "[I18N] Loading locale: #{locale} from #{file}"
          {:ok, kl} = :fast_yaml.decode_from_file "priv/lang/#{file}", plain_as_atom: true
          # It comes as [[key: value]] for w/e reason. fast_yaml plz
          tln = kl
                |> List.first
                |> Enum.reduce(%{}, fn({key, value}, acc) -> 
                    Map.put acc, key, value
                  end)
          
          Map.put l, locale, tln
        else
          Logger.info "Ignoring invalid localization file: #{file}"
          l
        end
      end)

    {:ok, lang}
  end

  def translate(lang, key) do
    Logger.debug "Got request to translate #{key} into locale #{lang}"
    GenServer.call __MODULE__, {:translate, lang, key}
  end

  def missing_arg(lang, cmd, args) when is_binary(cmd) and is_binary(args) do
    msg = GenServer.call __MODULE__, {:translate, lang, "message.missing-arg"}
    msg |> String.replace("$command", cmd)
        |> String.replace("$args", args)
  end

  def handle_call({:translate, lang, key}, _from, state) do
    # Turn the key into a list of atoms
    keys_w = String.split key, "."
    keys = keys_w |> Enum.map(fn(k) -> String.to_atom(k) end)
                  |> Enum.to_list
    if Map.has_key?(state, lang) do
      tln = get_in state[lang], keys
      unless is_nil tln do
        {:reply, tln, state}
      else
        # Fall back to en if no translation available
        unless lang == "en" do
          tln = get_in state["en"], keys
          unless is_nil tln do
            {:reply, tln, state}
          else
            {:reply, @unknown_translation, state}
          end
        end
        {:reply, @unknown_translation, state}
      end
    else
      {:reply, @unknown_translation, state}
    end
  end

  defp get_path(file) do
    Path.join @dir, file
  end
end