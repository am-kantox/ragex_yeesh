defmodule RagexYeeshWeb.TerminalLive do
  use RagexYeeshWeb, :live_view

  # Streaming chunks are accumulated and flushed as a batch to avoid
  # overwhelming the WebSocket. Every @flush_interval_ms, buffered
  # text is pushed as a single `ragex:stream_chunk` event.
  @flush_interval_ms 50

  @impl true
  def mount(_params, _session, socket) do
    commands = [
      RagexYeesh.Commands.Analyze,
      RagexYeesh.Commands.Audit,
      RagexYeesh.Commands.Chat,
      RagexYeesh.Commands.Dashboard,
      RagexYeesh.Commands.Refactor,
      RagexYeesh.Commands.Configure,
      RagexYeesh.Commands.CacheStats,
      RagexYeesh.Commands.CacheClear,
      RagexYeesh.Commands.CacheRefresh,
      RagexYeesh.Commands.EmbeddingsMigrate,
      RagexYeesh.Commands.ModelsDownload,
      RagexYeesh.Commands.AiUsageStats,
      RagexYeesh.Commands.AiCacheStats,
      RagexYeesh.Commands.AiCacheClear,
      RagexYeesh.Commands.Completions,
      RagexYeesh.Commands.InstallMan
    ]

    socket =
      socket
      |> assign(ragex_commands: commands)
      |> assign(stream_buffer: "", stream_timer: nil)

    {:ok, socket}
  end

  # -- Streaming chunk handling -----------------------------------------------
  #
  # Chunks from `on_chunk` callbacks arrive at high frequency.  We buffer
  # them and flush once per @flush_interval_ms so the browser gets one
  # manageable push_event per tick instead of hundreds of tiny ones.

  @impl true
  def handle_info({:ragex_stream_chunk, text}, socket) do
    buffer = socket.assigns.stream_buffer <> text

    socket =
      if is_nil(socket.assigns.stream_timer) do
        timer = Process.send_after(self(), :ragex_flush_stream, @flush_interval_ms)
        assign(socket, stream_buffer: buffer, stream_timer: timer)
      else
        assign(socket, stream_buffer: buffer)
      end

    {:noreply, socket}
  end

  def handle_info(:ragex_flush_stream, socket) do
    socket = flush_stream_buffer(socket)
    {:noreply, socket}
  end

  def handle_info({:ragex_stream_done, content}, socket) when is_binary(content) do
    # Flush any remaining raw buffer, then send the Marcli-rendered
    # version so the frontend can replace the raw stream with it.
    rendered = Marcli.render(content, newline: "\r\n")

    socket =
      socket
      |> flush_stream_buffer()
      |> push_event("ragex:stream_done", %{formatted: rendered})

    {:noreply, socket}
  end

  # Fallback when no content is provided (legacy callers)
  def handle_info(:ragex_stream_done, socket) do
    socket =
      socket
      |> flush_stream_buffer()
      |> push_event("ragex:stream_done", %{})

    {:noreply, socket}
  end

  # -- Chat interactive mode --------------------------------------------------

  def handle_info({:ragex_chat_ready, chat_server, prompt}, socket) do
    # The ChatServer is ready for Q&A. Switch the Yeesh session to
    # :mix_task mode so the executor routes user input through it.
    session_pid = get_session_pid(socket)

    if session_pid do
      Yeesh.Session.update(session_pid, fn s ->
        %{
          s
          | mode: :mix_task,
            context:
              Map.merge(s.context, %{
                mix_io_server: chat_server,
                mix_task_pid: chat_server,
                mix_prompt: prompt
              })
        }
      end)
    end

    socket = push_event(socket, "yeesh:prompt", %{prompt: prompt})
    {:noreply, socket}
  end

  # Legacy handler kept for backward compat with any IOServer-based commands
  def handle_info(
        {:chat_interactive, output, io_server, task_pid, original_shell, prompt, _session},
        socket
      ) do
    session_pid = get_session_pid(socket)

    if session_pid do
      Yeesh.Session.update(session_pid, fn s ->
        %{
          s
          | mode: :mix_task,
            context:
              Map.merge(s.context, %{
                mix_io_server: io_server,
                mix_task_pid: task_pid,
                mix_prompt: prompt,
                mix_original_shell: original_shell
              })
        }
      end)
    end

    socket =
      socket
      |> push_event("ragex:async_output", %{output: output})
      |> push_event("yeesh:prompt", %{prompt: prompt})

    {:noreply, socket}
  end

  # -- One-shot result / error ------------------------------------------------

  def handle_info({:ragex_task_result, output}, socket) do
    {:noreply, push_event(socket, "ragex:async_output", %{output: output})}
  end

  def handle_info({:ragex_task_error, reason}, socket) do
    {:noreply, push_event(socket, "ragex:async_error", %{error: reason})}
  end

  # -- Helpers ----------------------------------------------------------------

  defp flush_stream_buffer(socket) do
    buffer = socket.assigns.stream_buffer

    socket =
      if buffer != "" do
        push_event(socket, "ragex:stream_chunk", %{text: buffer})
      else
        socket
      end

    assign(socket, stream_buffer: "", stream_timer: nil)
  end

  defp get_session_pid(_socket) do
    Process.get(:yeesh_session_pid)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex flex-col items-center gap-6 w-full max-w-5xl mx-auto">
        <div class="text-center space-y-2">
          <h1 class="text-3xl font-bold tracking-tight">Ragex Terminal</h1>
          <p class="text-base-content/60 text-sm">
            Browser-based access to all Ragex code analysis tools.
            Type <code class="px-1.5 py-0.5 rounded bg-base-300 text-sm font-mono">help</code>
            to see available commands,
            <code class="px-1.5 py-0.5 rounded bg-base-300 text-sm font-mono">analyze</code>
            to analyze code,
            <code class="px-1.5 py-0.5 rounded bg-base-300 text-sm font-mono">chat</code>
            for interactive Q&A, or
            <code class="px-1.5 py-0.5 rounded bg-base-300 text-sm font-mono">mix &lt;task&gt;</code>
            for any Mix task.
          </p>
        </div>

        <div id="async-bridge" phx-hook="AsyncBridge" />

        <div
          id="terminal-container"
          class="w-full rounded-xl overflow-hidden shadow-2xl border border-base-300"
          style="height: 560px;"
        >
          <.live_component
            module={Yeesh.Live.TerminalComponent}
            id="ragex-terminal"
            commands={@ragex_commands}
            prompt="ragex> "
            theme={:default}
          />
        </div>

        <div class="flex flex-wrap gap-2 justify-center text-xs text-base-content/40">
          <span class="px-2 py-1 rounded-full bg-base-200">Tab: autocomplete</span>
          <span class="px-2 py-1 rounded-full bg-base-200">Up/Down: history</span>
          <span class="px-2 py-1 rounded-full bg-base-200">Ctrl+C: interrupt</span>
          <span class="px-2 py-1 rounded-full bg-base-200">Ctrl+L: clear</span>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
