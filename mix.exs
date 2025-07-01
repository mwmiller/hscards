defmodule HSCards.MixProject do
  use Mix.Project

  def project do
    [
      app: :hscards,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
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
      {:sqlite_vec, "~> 0.1.0"},
      {:ecto_sqlite3, "~> 0.19.0"},
      {:jason, "~> 1.0"},
      {:varint, "~> 1.5"},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/helpers"]
  defp elixirc_paths(_), do: ["lib"]
end
