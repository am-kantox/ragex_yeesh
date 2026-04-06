defmodule RagexYeeshWeb.TerminalLive do
  use RagexYeeshWeb, :live_view

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

    {:ok, assign(socket, ragex_commands: commands)}
  end

  @impl true
  def handle_info({:ragex_task_result, output}, socket) do
    {:noreply, push_event(socket, "ragex:async_output", %{output: output})}
  end

  def handle_info({:ragex_task_error, reason}, socket) do
    {:noreply, push_event(socket, "ragex:async_error", %{error: reason})}
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
