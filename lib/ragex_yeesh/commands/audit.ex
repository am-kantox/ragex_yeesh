defmodule RagexYeesh.Commands.Audit do
  @moduledoc """
  Run a comprehensive AI-powered code audit.

  Uses a two-phase approach so the AI report is **streamed**
  chunk-by-chunk into the Yeesh terminal:

  1. Analysis phase -- `Core.analyze_project/2` with `skip_report: true`.
  2. Report phase  -- `Core.stream_generate_report/3` with an `:on_chunk`
     callback that forwards each piece to the LiveView for throttled
     delivery to the frontend.

  ## Usage

      audit [options]

  ## Options

    * `--format FORMAT` - `json` (default) or `markdown`
    * `--dead-code`     - Include dead-code analysis
    * `--provider P`    - AI provider override
    * `--model M`       - Model name override
  """

  @behaviour Yeesh.Command

  alias Ragex.Agent.Core

  @impl true
  def name, do: "audit"

  @impl true
  def description, do: "Run a comprehensive AI-powered code audit"

  @impl true
  def usage do
    if Code.ensure_loaded?(Mix) do
      case Mix.Task.get("ragex.audit") do
        nil ->
          "audit [options]"

        mod ->
          case Code.fetch_docs(mod) do
            {:docs_v1, _, _, _, %{"en" => doc}, _, _} ->
              Marcli.render(doc, newline: "\r\n")

            _ ->
              "audit [options]"
          end
      end
    else
      "audit [options]"
    end
  end

  @impl true
  def execute(args, session) do
    Application.put_env(:ragex, :start_server, false)
    Application.ensure_all_started(:ragex)

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          format: :string,
          dead_code: :boolean,
          provider: :string,
          model: :string
        ],
        aliases: [f: :format, m: :model]
      )

    caller = self()
    working_dir = RagexYeesh.Config.working_dir()
    format = Keyword.get(opts, :format, "markdown")

    Task.start(fn ->
      run_audit(caller, working_dir, format, opts)
    end)

    {:ok, "Running audit on #{working_dir} ...\r\n", session}
  end

  # -- Private ---------------------------------------------------------------

  defp run_audit(caller, path, format, opts) do
    core_opts =
      [
        include_dead_code: Keyword.get(opts, :dead_code, false),
        skip_embeddings: false,
        skip_report: true,
        verbose: false
      ]
      |> maybe_put(:provider, parse_provider(opts[:provider]))
      |> maybe_put(:model, opts[:model])

    # Phase 1: Analysis (no AI report yet)
    case Core.analyze_project(path, core_opts) do
      {:ok, result} ->
        send(caller, {:ragex_stream_chunk, "Analysis complete. Generating report...\r\n"})

        # Phase 2: Stream the AI report
        stream_report(caller, path, result, format, opts)

      {:error, reason} ->
        send(caller, {:ragex_task_error, "Audit failed: #{inspect(reason)}"})
    end
  rescue
    e ->
      send(caller, {:ragex_task_error, "Audit crashed: #{Exception.message(e)}"})
  catch
    :exit, reason ->
      send(caller, {:ragex_task_error, "Audit exited: #{inspect(reason)}"})
  end

  defp stream_report(caller, _path, result, "json", _opts) do
    # JSON format cannot be streamed meaningfully; send the whole blob.
    output = Jason.encode!(result, pretty: true)
    send(caller, {:ragex_task_result, output})
  end

  defp stream_report(caller, path, result, _markdown, opts) do
    on_chunk = fn
      %{content: text} when is_binary(text) and text != "" ->
        send(caller, {:ragex_stream_chunk, text})

      _ ->
        :ok
    end

    stream_opts =
      [on_chunk: on_chunk, verbose: false]
      |> maybe_put(:provider, parse_provider(opts[:provider]))
      |> maybe_put(:model, opts[:model])

    case Core.stream_generate_report(path, result.issues, stream_opts) do
      {:ok, content, _ai_status} ->
        send(caller, {:ragex_stream_done, content})

      {:error, reason} ->
        send(caller, {:ragex_task_error, "Report generation failed: #{inspect(reason)}"})
    end
  end

  defp parse_provider(nil), do: nil
  defp parse_provider(name), do: String.to_existing_atom(name)

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
