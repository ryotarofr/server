defmodule SimpleServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :simple_server,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {SimpleServer.Application, []}
    ]
  end

  defp deps do
    [
      {:cowboy, "~> 2.8"},
      {:jason, "~> 1.0"},
      {:uuid, "~> 1.1"}
    ]
  end
end