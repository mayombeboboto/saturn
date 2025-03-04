defmodule Saturn.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SaturnWeb.Telemetry,
      Saturn.Repo,
      {DNSCluster, query: Application.get_env(:saturn, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Saturn.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Saturn.Finch},
      # Start a worker by calling: Saturn.Worker.start_link(arg)
      # {Saturn.Worker, arg},
      # Start to serve requests, typically the last entry
      SaturnWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Saturn.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SaturnWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
