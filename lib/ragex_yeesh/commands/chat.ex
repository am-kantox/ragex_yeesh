if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.Chat do
    @moduledoc """
    Interactive codebase Q&A powered by RAG.

    Calls Ragex APIs directly (bypassing the Mix task and IOServer) so that
    the AI response is **streamed** chunk-by-chunk into the Yeesh terminal
    while keeping the LiveView responsive.

    ## Flow

    1. `execute/2` returns immediately ("Starting chat session...").
    2. A background task runs project analysis (`Core.analyze_project`
       with `skip_report: true`).
    3. The AI report is streamed via `Core.stream_generate_report` --
       each chunk is forwarded to the LiveView which pushes it to the
       terminal.
    4. After the report, a `RagexYeesh.ChatServer` is started and the
       Yeesh session is switched to `:mix_task` mode so subsequent user
       inputs are routed through the ChatServer.
    5. Each question is answered via `Core.stream_chat` with real-time
       chunk forwarding.
    """

    @behaviour Yeesh.Command

    alias Ragex.Agent.Core
    alias RagexYeesh.ChatServer

    @impl true
    def name, do: "chat"

    @impl true
    def description, do: "Interactive codebase Q&A powered by RAG"

    @impl true
    def usage do
      case Mix.Task.get("ragex.chat") do
        nil ->
          "chat [args...]"

        task_module ->
          case Code.fetch_docs(task_module) do
            {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} ->
              Marcli.render(moduledoc, newline: "\r\n")

            _ ->
              "chat [args...]"
          end
      end
    end

    @impl true
    def execute(args, session) do
      Application.put_env(:ragex, :start_server, false)
      Application.ensure_all_started(:ragex)

      {opts, _, _} =
        OptionParser.parse(args,
          strict: [
            provider: :string,
            model: :string,
            dead_code: :boolean,
            skip_analysis: :boolean
          ],
          aliases: [m: :model]
        )

      caller = self()
      working_dir = RagexYeesh.Config.working_dir()

      # Stash the session_pid so handle_info can switch to interactive mode
      Process.put(:yeesh_session_pid, find_session_pid())

      Task.start(fn ->
        run_chat_setup(caller, working_dir, opts)
      end)

      {:ok, "Starting chat session...\r\n", session}
    end

    # -- Private ---------------------------------------------------------------

    defp run_chat_setup(caller, path, opts) do
      core_opts =
        [
          include_dead_code: Keyword.get(opts, :dead_code, false),
          skip_embeddings: false,
          skip_report: true,
          verbose: false
        ]
        |> maybe_put(:provider, parse_provider(opts[:provider]))
        |> maybe_put(:model, opts[:model])

      # Phase 1: Analyze the project (skip AI report)
      case Core.analyze_project(path, core_opts) do
        {:ok, result} ->
          send(caller, {:ragex_stream_chunk, "Analysis complete.\r\n"})

          # Phase 2: Stream the AI report
          session_id = stream_report(caller, path, result.issues, opts)

          # Phase 3: Enter interactive mode via ChatServer
          enter_interactive(caller, session_id, path, opts)

        {:error, reason} ->
          send(caller, {:ragex_task_error, "Analysis failed: #{inspect(reason)}"})
      end
    rescue
      e ->
        send(caller, {:ragex_task_error, "Chat setup crashed: #{Exception.message(e)}"})
    end

    defp stream_report(caller, path, issues, opts) do
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

      case Core.stream_generate_report(path, issues, stream_opts) do
        {:ok, content, _ai_status} ->
          send(caller, {:ragex_stream_done, content})

          # Retrieve the session created by stream_generate_report
          case Core.list_sessions(limit: 1) do
            [%{id: session_id} | _] -> session_id
            _ -> nil
          end

        {:error, reason} ->
          send(caller, {:ragex_task_error, "Report generation failed: #{inspect(reason)}"})
          nil
      end
    end

    defp enter_interactive(caller, nil, _path, _opts) do
      send(caller, {:ragex_task_error, "Could not establish chat session."})
    end

    defp enter_interactive(caller, session_id, path, opts) do
      prompt = "ragex> "

      {:ok, chat_server} =
        ChatServer.start_link(
          session_id: session_id,
          caller: caller,
          path: path,
          provider: parse_provider(opts[:provider]),
          model: opts[:model],
          prompt: prompt
        )

      send(caller, {:ragex_chat_ready, chat_server, prompt})
    end

    # Finds the Yeesh session pid owned by the current LiveView process.
    defp find_session_pid do
      case DynamicSupervisor.which_children(Yeesh.SessionSupervisor) do
        [] ->
          nil

        children ->
          Enum.find_value(children, fn
            {:undefined, pid, :worker, _} when is_pid(pid) -> pid
            _ -> nil
          end)
      end
    rescue
      _ -> nil
    end

    defp parse_provider(nil), do: nil
    defp parse_provider(name) when is_atom(name), do: name
    defp parse_provider(name) when is_binary(name), do: String.to_existing_atom(name)

    defp maybe_put(opts, _key, nil), do: opts
    defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
  end
end
