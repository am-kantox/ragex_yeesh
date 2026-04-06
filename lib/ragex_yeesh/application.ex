defmodule RagexYeesh.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    working_dir = RagexYeesh.Config.resolve_working_dir!()

    require Logger
    Logger.info("RagexYeesh working directory: #{working_dir}")

    children = [
      RagexYeeshWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:ragex_yeesh, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RagexYeesh.PubSub},
      RagexYeeshWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: RagexYeesh.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def start_phase(:preload, _start_type, _phase_args) do
    working_dir = RagexYeesh.Config.working_dir()

    RagexYeesh.Preloader.start_ragex!()
    RagexYeesh.Preloader.analyze_async(working_dir)

    :ok
  end

  @impl true
  def config_change(changed, _new, removed) do
    RagexYeeshWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
