defmodule Alice.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    Logger.info "[APP] Starting..."
    {:ok, _agent_pid} = Alice.CommandState.start_link
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Alice.Worker.start_link(arg)
      # {Alice.Worker, arg},
      {Alice.I18n, []},
      # Really ScyllaDB, but it's API-compatible with Cassandra, so it's basically the same thing
      %{
        id: Xandra,
        start: {Xandra, :start_link, [[
            nodes: [System.get_env("CASSANDRA_NODE")], 
            pool: DBConnection.Poolboy,
            name: :cache
          ]]},
        type: :worker,
        restart: :permanent,
        shutdown: 500,
      },
      # Used for real data
      Mongo.child_spec([
          name: :mongo, 
          database: System.get_env("MAIN_DATABASE"), 
          pool: DBConnection.Poolboy, 
          hostname: System.get_env("MONGO_IP"), 
          port: "27017"
        ], [id: :mongo]),
      {Gnat, %{host: System.get_env("NATS_IP")}},
      {Lace.Redis, %{
          redis_ip: System.get_env("REDIS_IP"), redis_port: 6379, pool_size: 500, redis_pass: System.get_env("REDIS_PASS")
        }},
      Emily.Ratelimiter,
      Plug.Adapters.Cowboy.child_spec(:http, Alice.Router, [], [
          dispatch: dispatch(),
          port: get_port(),
        ]),
      {Alice.EventProcessor, %{}}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Alice.Supervisor]
    {:ok, sup_res} = Supervisor.start_link(children, opts)

    Logger.info "[API] Starting API clients..."
    Alice.ApiClient.start()
    Alice.Hotspring.start()
    Alice.Shard.start()

    Alice.CommandState.add_commands Alice.Cmd.Owner
    Alice.CommandState.add_commands Alice.Cmd.Emote
    Alice.CommandState.add_commands Alice.Cmd.Utility
    Alice.CommandState.add_commands Alice.Cmd.Fun
    Alice.CommandState.add_commands Alice.Cmd.Currency
    Alice.CommandState.add_commands Alice.Cmd.Music
    Alice.CommandState.add_commands Alice.Cmd.Dnd
    Alice.CommandState.add_commands Alice.Cmd.Levels

    Logger.info "[DB] Prepping Cassandra..."
    Alice.Cache.prep_db()
    Logger.info "[DB] Done!"

    # For some fucking reason, gnat is retarded and won't actually 
    # register a name for itself, it seems? x-x
    # This forcibly registers it to :gnat to work around this
    # queer behaviour.
    for {name, pid, _, _} <- Supervisor.which_children(sup_res) do
      if name == Gnat do
        Process.register pid, :gnat
      end
    end

    send Alice.EventProcessor, :setup

    Logger.info "[APP] Fully up!"

    # Start the processing task
    #Task.async fn -> Alice.EventProcessor.process() end

    {:ok, sup_res}
  end

  defp get_port do
    x = System.get_env "PORT"
    case x do
      nil -> 8888
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
