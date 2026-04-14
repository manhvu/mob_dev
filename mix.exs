defmodule MobDev.MixProject do
  use Mix.Project

  def project do
    [
      app: :mob_dev,
      version: "0.2.2",
      elixir: "~> 1.17",
      description: "Project runner for the Mob mobile framework",
      deps: deps(),
      package: package()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:eqrcode, "~> 0.2"},
      {:jason, "~> 1.4"},
      {:avatarz, "~> 0.2"},
      {:image, "~> 0.54"},
      # Dev server
      {:phoenix_live_view, "~> 1.0"},
      {:bandit, "~> 1.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:plug_crypto, "~> 2.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:jump_credo_checks, "~> 0.1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/genericjam/mob_dev"}
    ]
  end
end
