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
      Alice.ReadRepo,
      Alice.WriteRepo,
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
        ]),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Alice.Supervisor]
    {:ok, sup_res} = Supervisor.start_link(children, opts)

    Logger.info "[APP] Waiting for everything to be up..."
    :timer.sleep 1000
    Logger.info "[APP] Everything: "
    Logger.info "[APP] #{inspect Supervisor.which_children(sup_res), pretty: true} "

    Logger.info "[DB] Making database if needed..."
    db_conf = Application.get_env(:alice, Alice.WriteRepo)
    case Ecto.Adapters.Postgres.storage_up([
          database: db_conf[:database],
          username: db_conf[:username],
          password: db_conf[:password],
          hostname: db_conf[:hostname],
        ]) do
      :ok ->
        Logger.info "[DB] The database has been created"
      {:error, :already_up} ->
        Logger.info "[DB] The database has already been created"
      {:error, term} when is_binary(term) ->
        Logger.warn "[DB] The database couldn't be created: #{term}"
      {:error, term} ->
        Logger.warn "[DB] The database couldn't be created: #{inspect term}"
    end
    Logger.info "[DB] Running database migrations..."
    migration_res = Ecto.Migrator.run(Alice.WriteRepo, Application.app_dir(:alice, "priv/write_repo/migrations"), :up, [all: true])
    Logger.info "[DB] Migration result: #{inspect migration_res}"

    Alice.CommandState.add_commands Alice.Cmd.Owner
    Alice.CommandState.add_commands Alice.Cmd.Emote
    Alice.CommandState.add_commands Alice.Cmd.Utility
    Alice.CommandState.add_commands Alice.Cmd.Fun
    Alice.CommandState.add_commands Alice.Cmd.Currency

    Logger.info "[APP] Fully up!"

    # Start the processing task
    Task.async fn -> Alice.EventProcessor.process() end

    {:ok, sup_res}
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
