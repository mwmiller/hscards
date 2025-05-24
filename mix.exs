defmodule Hscards.MixProject do
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
      extra_applications: [:logger, :inets, :ssl]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:varint, "~> 1.5"}, {:ex_doc, "~> 0.30", only: :dev, runtime: false}]
  end
end
