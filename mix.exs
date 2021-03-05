defmodule Fika.MixProject do
  use Mix.Project

  @app :fika

  def project do
    [
      app: @app,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: Fika.Cli],
      deps: deps(),
      xref: [exclude: [:router]],
      elixirc_paths: elixirc_paths(Mix.env()),
      releases: [{@app, release()}],
      preferred_cli_env: [release: :prod],
      compilers: Mix.compilers() ++ [:fika]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:logger], mod: {Fika.Application, []}]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_parsec, "~> 1.1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:file_system, "~> 0.2"},
      {:finch, "~> 0.3"},
      {:jason, "~> 1.2"},
      {:bakeware, "~> 0.1.4", runtime: false}
    ]
  end

  defp release do
    [
      overwrite: true,
      cookie: "#{@app}_cookie",
      steps: [:assemble, &Bakeware.assemble/1, &Fika.Deployment.copy_files/1],
      strip_beams: Mix.env() == :prod,
      quiet: true
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(_), do: ["lib"]
end
