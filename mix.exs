defmodule Libelection.Mixfile do
  use Mix.Project

  def project do
    [app: :libelection,
     version: "0.2.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: "Library to perform leader election in a cluster of containerized Elixir nodes",
     package: package(),
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: [
       "coveralls": :test,
       "coveralls.detail": :test,
       "coveralls.post": :test,
       "coveralls.travis": :test,
       "coveralls.html": :test],
     docs: docs(),
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [mod: {Election.App, []}, extra_applications: [:logger, :poison]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:poison, "~> 3.0"},
     {:ex_doc, "~> 0.13", only: :dev},
     {:dialyxir, "~> 0.3", only: :dev},
     {:credo, "~> 0.8", only: [:dev, :test]},
     {:bypass, github: "PSPDFKit-labs/bypass", only: :test},
     {:excoveralls, "~> 0.8", only: :test},
     {:inch_ex, "~> 0.5", only: :docs}]
  end

  defp package do
    [files: ["lib", "mix.exs", "README.md", "LICENSE.md"],
     maintainers: ["Dimitris Zorbas"],
     licenses: ["GPLv3"],
     links: %{"GitHub": "https://github.com/quiqupltd/libelection"}]
  end

  defp docs do
    [main: "readme",
     formatter_opts: [gfm: true],
     extras: [
       "README.md"
     ]]
  end
end
