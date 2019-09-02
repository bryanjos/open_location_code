defmodule OpenLocationCode.MixProject do
  use Mix.Project

  def project do
    [
      app: :open_location_code,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:stream_data, "~> 0.4.3", only: :test},
      {:ex_doc, "~> 0.21", only: :dev},
      {:benchee, "~> 1.0", only: :dev},
      {:geo, "~> 3.3"}
    ]
  end
end
