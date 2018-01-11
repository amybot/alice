defmodule Alice.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Alice.Worker.start_link(arg)
      # {Alice.Worker, arg},
      {Lace.Redis, %{
          redis_ip: System.get_env("REDIS_IP"), redis_port: 6379, pool_size: 100, redis_pass: System.get_env("REDIS_PASS")
        }},
      Emily.Ratelimiter,
      Plug.Adapters.Cowboy.child_spec(:http, Alice.Router, [], [
          dispatch: dispatch(),
          port: get_port(),
        ])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Alice.Supervisor]
    sup_res = Supervisor.start_link(children, opts)

    # Start the processing task
    Task.async fn -> Alice.EventProcessor.process() end

    Logger.info "Started!"
    sup_res
  end

  defp get_port do
    x = System.get_env "PORT"
    case x do
      nil -> 8080
      _ -> x |> String.to_integer
    end
  end

  defp dispatch do
    [
      {:_, [
        {:_, Plug.Adapters.Cowboy.Handler, {Alice.Router, []}}
      ]},
    ]
  end
end
