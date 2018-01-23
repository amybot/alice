defmodule Alice.Shard do
  @moduledoc """
  TODO
  """

  use HTTPoison.Base
  require Logger

  def process_url(url) do
    System.get_env("SHARD_API") <> url
  end

  def process_response_body(body) do
    body |> Poison.decode!
  end

  def get_self do
    get!("/self").body |> Poison.decode!
  end

  def get_self_id do
    get_self()["id"] |> Integer.to_string
  end

  def get_shard_count do
    get!("/shard/count").body["shard_count"]
  end

  def get_voice_connect_data(guild, channel) when is_binary(guild) and is_binary(channel) do
    voice_data = get! "/voice/#{guild}/#{channel}/connect", [], [timeout: 60_000, recv_timeout: 60_000]
    Logger.debug "Got voice data: #{inspect voice_data}"
    voice_data.body
  end

  def voice_disconnect(guild) when is_binary(guild) do
    get! "/voice/#{guild}/disconnect"
  end
end