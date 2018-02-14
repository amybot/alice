defmodule Alice.ApiClient do
  @moduledoc """
  Client for accessing the internal amybot API.
  """

  use HTTPoison.Base
  require Logger

  def process_url(url) do
    System.get_env("API_BASE") <> url
  end

  def process_response_body(body) do
    body |> Poison.decode!
  end

  def image(type, nsfw \\ false) when is_binary(type) 
                                  and is_boolean(nsfw) do
    route = case nsfw do
              false -> "/image/#{type}"
              true -> "/image/#{type}/nsfw"
            end
    get!(route).body["url"]
  end

  def dnd(type, search) when is_binary(type) and is_binary(search) do
    post!("/dnd/#{type}", Poison.encode!(%{"search" => search}), [{"Content-Type", "application/json"}]).body |> Poison.decode!
  end

  def radio(mode, search) do
    case mode do
      :keyword -> 
        post!("/radio", Poison.encode!(%{"search" => search}), [{"Content-Type", "application/json"}]).body
      :song ->
        post!("/radio/song", Poison.encode!(%{"search" => search}), [{"Content-Type", "application/json"}]).body
      :random ->
        post!("/radio/random", "", [{"Content-Type", "application/json"}]).body
    end
  end
end