if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.Chat do
    @moduledoc """
    Interactive codebase Q&A powered by RAG.

    Launches the `ragex.chat` Mix task in a non-blocking way:
    1. Spawns the task with a `Yeesh.IOServer` in a background process
    2. Returns immediately so the LiveView stays responsive
    3. Streams analysis output to the terminal via `{:ragex_task_result, ...}`
    4. When the task calls `IO.gets`, switches the session to `:mix_task`
       interactive mode for back-and-forth Q&A
    """

    @behaviour Yeesh.Command

    alias Yeesh.IOServer

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

      full_args = build_args(args)
      caller = self()

      # Stash the session_pid in the process dict so the LiveView's
      # handle_info can retrieve it to switch to interactive mode.
      # The Executor passes the struct (not pid), but we can find the
      # pid via DynamicSupervisor since we're in the LiveView process.
      session_pid = find_session_pid()
      Process.put(:yeesh_session_pid, session_pid)

      # Start IOServer and spawn the task
      {:ok, io_server} = IOServer.start_link()
      original_shell = Mix.shell()

      if Code.ensure_loaded?(Yeesh.MixShell) do
        Mix.shell(Yeesh.MixShell)
      end

      task_pid =
        spawn(fn ->
          Process.group_leader(self(), io_server)

          try do
            Mix.Task.rerun("ragex.chat", full_args)
          rescue
            e -> IO.puts("Error: #{Exception.message(e)}")
          end
        end)

      IOServer.monitor_task(io_server, task_pid)

      # Poll the IOServer in a background task so we don't block the LiveView.
      # When the ragex.chat task finishes analysis and calls IO.gets,
      # we notify the LiveView to switch to interactive mode.
      Task.start(fn ->
        wait_for_interactive(io_server, task_pid, original_shell, caller, session)
      end)

      {:ok, "Starting chat session...\r\n", session}
    end

    # Polls the IOServer without blocking the LiveView process.
    # When the task becomes interactive (IO.gets), sends a message
    # to switch the session to :mix_task mode and push the buffered
    # output. When the task completes without becoming interactive,
    # sends the output as an async result.
    defp wait_for_interactive(io_server, task_pid, original_shell, caller, session) do
      case IOServer.start_and_wait(io_server, timeout: :infinity) do
        {output, :waiting, prompt} ->
          # Task is now interactive -- tell the LiveView to enter mix_task mode
          send(
            caller,
            {:chat_interactive, output, io_server, task_pid, original_shell, prompt, session}
          )

        {output, :done} ->
          # Task finished without becoming interactive
          IOServer.stop(io_server)
          Mix.shell(original_shell)

          if output != "" do
            send(caller, {:ragex_task_result, output})
          end
      end
    rescue
      _ ->
        send(caller, {:ragex_task_error, "Chat session failed to start"})
    end

    defp build_args(args) do
      stripped = strip_path_args(args, [])
      ["--path", RagexYeesh.Config.working_dir() | stripped]
    end

    defp strip_path_args([], acc), do: Enum.reverse(acc)
    defp strip_path_args(["--path", _value | rest], acc), do: strip_path_args(rest, acc)
    defp strip_path_args(["-p", _value | rest], acc), do: strip_path_args(rest, acc)

    defp strip_path_args([<<"--path=", _rest::binary>> | rest], acc),
      do: strip_path_args(rest, acc)

    defp strip_path_args([head | rest], acc), do: strip_path_args(rest, [head | acc])

    # Finds the Yeesh session pid owned by the current LiveView process.
    # Sessions are started under Yeesh.SessionSupervisor.
    defp find_session_pid do
      case DynamicSupervisor.which_children(Yeesh.SessionSupervisor) do
        [] ->
          nil

        children ->
          # In a single-terminal LiveView there's typically one session.
          # Find the one whose links include self() (the LiveView process).
          Enum.find_value(children, fn
            {:undefined, pid, :worker, _} when is_pid(pid) -> pid
            _ -> nil
          end)
      end
    rescue
      _ -> nil
    end
  end
end
