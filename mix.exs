defmodule HSCards.MixProject do
  use Mix.Project

  def project do
    [
      app: :hscards,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets, :ssl],
      mod: {HSCards.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sqlite3, "~> 0.19.0"},
      {:cubdb, "~> 2.0"},
      {:varint, "~> 1.5"},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end
end
