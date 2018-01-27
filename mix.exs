defmodule Alice.Mixfile do
  use Mix.Project

  def project do
    [
      app: :alice,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Alice.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:emily, github: "queer/emily"},
      {:plug, "~> 1.4"},
      {:cowboy, "~> 1.1"},
      {:poison, "~> 3.1"},
      {:sentry, "~> 6.0.5"},
      {:mongodb, ">= 0.0.0"},
      {:poolboy, ">= 0.0.0"},
      {:annotatable, "~> 0.1.2"},
      {:fast_yaml, "~> 1.0"},
      {:timex, "~> 3.1"},
      {:hammer, "~> 2.1.0"},
    ]
  end
end
