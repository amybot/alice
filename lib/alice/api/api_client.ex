defmodule Alice.ApiClient do
  @moduledoc """
  Client for accessing the amybot API. You will need an API key with sufficient
  permissions in order to use the majority of the routes. 
  """

  use HTTPoison.Base

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
end