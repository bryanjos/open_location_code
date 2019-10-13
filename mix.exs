defmodule OpenLocationCode.MixProject do
  use Mix.Project

  def project do
    [
      app: :open_location_code,
      version: "1.0.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "OpenLocationCode",
      source_url: "https://github.com/bryanjos/open_location_code"
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
      {:benchee, "~> 1.0", only: :dev}
    ]
  end

  defp description do
    """
    Elixir implementation of Open Location Code library
    """
  end

  defp package do
    # These are the default files included in the package
    [
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md"],
      maintainers: ["Bryan Joseph"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/bryanjos/open_location_code"}
    ]
  end
end
