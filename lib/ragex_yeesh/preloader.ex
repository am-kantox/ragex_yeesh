defmodule RagexYeesh.Preloader do
  @moduledoc """
  Bootstraps the Ragex runtime and pre-analyzes the working directory.

  Called from `RagexYeesh.Application.start_phase/3` after the
  supervision tree is running.  Two things happen:

    1. The `:ragex` OTP application is started synchronously (it is
       declared `runtime: false` so OTP does not start it on its own).
       This loads the Bumblebee embedding model onto the GPU.

    2. A background `Task` analyzes `RAGEX_WORKING_DIR` so the
       knowledge graph and embeddings are ready before the first
       interactive command.
  """

  require Logger

  @doc """
  Starts the ragex OTP application (synchronous).

  Suppresses the MCP server since we only need the analysis runtime.
  """
  @spec start_ragex!() :: :ok
  def start_ragex! do
    Application.put_env(:ragex, :start_server, false)

    case Application.ensure_all_started(:ragex) do
      {:ok, apps} ->
        if apps != [] do
          Logger.info("Ragex runtime started (#{length(apps)} apps)")
        end

        :ok

      {:error, reason} ->
        Logger.error("Failed to start ragex: #{inspect(reason)}")
        :ok
    end
  end

  @doc """
  Analyzes the working directory in the background.

  Uses `Core.quick_analyze/2` which goes through `Store.load_project/1`
  first -- this loads the cached graph and embeddings from disk when
  available, skipping the expensive embedding generation on subsequent
  starts.
  """
  @spec analyze_async(String.t()) :: {:ok, pid()}
  def analyze_async(working_dir) do
    Task.start(fn ->
      try do
        Logger.info("Pre-loading: analyzing #{working_dir} ...")

        case Ragex.Agent.Core.quick_analyze(working_dir) do
          {:ok, %{summary: summary}} ->
            Logger.info(
              "Pre-loading complete: #{summary.total_issues} issues found"
            )

          {:ok, result} ->
            Logger.info("Pre-loading complete: #{inspect(Map.keys(result))}")

          {:error, reason} ->
            Logger.warning("Pre-loading analysis failed: #{inspect(reason)}")
        end
      rescue
        e ->
          Logger.warning("Pre-loading error: #{Exception.message(e)}")
      end
    end)
  end
end
