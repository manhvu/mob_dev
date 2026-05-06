defmodule DalaDev.MixProject do
  use Mix.Project

  def project do
    [
      app: :dala_dev,
      version: "0.0.4",
      elixir: "~> 1.18",
      description: "Development tooling for the Dala framework",
      source_url: "https://github.com/manhvu/dala_dev",
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:eqrcode, "~> 0.2"},
      {:jason, "~> 1.4"},
      {:avatarz, "~> 0.2", optional: true},
      {:image, "~> 0.54", optional: true},
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

  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/manhvu/dala_dev",
      source_url_pattern: "https://github.com/manhvu/dala_dev/blob/main/%{path}#L%{line}",
      extras: [
        "README.md": [title: "dala_dev"],
        "guides/publishing_to_testflight.md": [title: "Publishing to TestFlight (iOS)"]
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      groups_for_modules: [
        "Mix Tasks": ~r/Mix\.Tasks\./,
        Server: ~r/DalaDev\.Server/,
        Internals: ~r/DalaDev/
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/manhvu/dala_dev"}
    ]
  end
end
