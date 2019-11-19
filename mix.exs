defmodule Data.MixProject do
  use Mix.Project

  def project do
    [
      app: :data,
      deps: deps(),
      description: "Elixir data structures extensions",
      docs: docs(),
      elixir: "~> 1.7",
      package: package(),
      start_permanent: Mix.env() == :prod,
      version: "0.1.0"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.5.1", runtime: false},
      {:error, "~> 0.1.0"},
      {:ex_doc, "~> 0.21.2", only: :dev, runtime: false},
      {:fe, "~> 0.1.2"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/well-ironed/data"}
    ]
  end
end