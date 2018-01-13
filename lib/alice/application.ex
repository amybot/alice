defmodule Alice.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    {:ok, _agent_pid} = Alice.CommandState.start_link
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Alice.Worker.start_link(arg)
      # {Alice.Worker, arg},
      {Alice.I18n, []},
      {Mongo, [
          name: :mongo, 
          database: System.get_env("CACHE_DATABASE"), 
          pool: DBConnection.Poolboy, 
          hostname: System.get_env("MONGO_IP"), 
          port: "27017"
        ]},
      {Lace.Redis, %{
          redis_ip: System.get_env("REDIS_IP"), redis_port: 6379, pool_size: 100, redis_pass: System.get_env("REDIS_PASS")
        }},
      Emily.Ratelimiter,
      Plug.Adapters.Cowboy.child_spec(:http, Alice.Router, [], [
          dispatch: dispatch(),
          port: get_port(),
        ])
    ]

    spawn fn -> 
        Logger.info "[APP] Waiting for everything to be up..."
        # lol
        :timer.sleep 1000

        Alice.CommandState.add_commands Alice.Cmd.Test, Alice.Cmd.Test.annotations()
        Alice.CommandState.add_commands Alice.Cmd.Emote, Alice.Cmd.Emote.annotations()

        Logger.info "[APP] Fully up!"

        # Start the processing task
        Task.async fn -> Alice.EventProcessor.process() end
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Alice.Supervisor]
    sup_res = Supervisor.start_link(children, opts)

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