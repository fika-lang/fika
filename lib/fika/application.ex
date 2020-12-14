defmodule Fika.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Fika.Compiler.TypeChecker.FunctionDependencies,
      Fika.Compiler.CodeServer
    ]

    children =
      if Application.get_env(:fika, :start_cli) do
        children ++ [%{id: Fika.Cli, start: {Fika.Cli, :start, [nil, nil]}}]
      else
        children
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fika.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
