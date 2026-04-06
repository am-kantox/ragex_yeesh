defmodule RagexYeesh.Commands.Audit do
  @moduledoc """
  Run a comprehensive AI-powered code audit.

  Calls the Ragex API directly (bypassing MixRunner) so that the
  AI report can be **streamed** chunk-by-chunk into the Yeesh
  terminal while keeping the LiveView responsive.

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
        nil -> "audit [options]"

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
        verbose: false
      ]
      |> maybe_put(:provider, parse_provider(opts[:provider]))
      |> maybe_put(:model, opts[:model])

    case Core.analyze_project(path, core_opts) do
      {:ok, result} ->
        output = format_result(result, format)
        send(caller, {:ragex_task_result, output})

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

  defp format_result(result, "json") do
    Jason.encode!(result, pretty: true)
  end

  defp format_result(result, _markdown) do
    case result.report do
      nil -> "No AI report was generated."
      "" -> "AI report is empty."
      report -> Marcli.render(report, newline: "\r\n")
    end
  end

  defp parse_provider(nil), do: nil
  defp parse_provider(name), do: String.to_existing_atom(name)

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
