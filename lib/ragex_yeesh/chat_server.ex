defmodule RagexYeesh.ChatServer do
  @moduledoc """
  Bridges the Yeesh executor's synchronous `IOServer.provide_input_and_wait`
  protocol with Ragex's asynchronous streaming APIs.

  When the Yeesh executor forwards a user question (via `{:provide_input, input}`),
  this server **replies immediately** with empty output so the LiveView process
  unblocks.  It then spawns a background task that calls
  `Ragex.Agent.Core.stream_chat/3` with an `:on_chunk` callback, forwarding
  each chunk to the LiveView via `send/2`.

  ## Lifecycle

  1. Started by `Commands.Chat` after initial analysis completes.
  2. Stored in the Yeesh session context as `:mix_io_server` (reuses the
     `:mix_task` mode machinery).
  3. Each user question triggers a streaming task; the result is pushed
     chunk-by-chunk to the terminal.
  4. Typing `exit` or `/quit` replies `:done`, causing the executor to
     clean up and return to `:normal` mode.
  """

  use GenServer

  alias Ragex.Agent.Core

  defstruct [
    :session_id,
    :caller,
    :path,
    :provider,
    :model,
    :prompt,
    busy: false
  ]

  # -- Public API -------------------------------------------------------------

  @doc "Starts the chat server."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Stops the chat server."
  @spec stop(GenServer.server()) :: :ok
  def stop(server) do
    GenServer.stop(server, :normal)
  catch
    :exit, _ -> :ok
  end

  # -- GenServer callbacks ----------------------------------------------------

  @impl true
  def init(opts) do
    state = %__MODULE__{
      session_id: Keyword.fetch!(opts, :session_id),
      caller: Keyword.fetch!(opts, :caller),
      path: Keyword.fetch!(opts, :path),
      provider: Keyword.get(opts, :provider),
      model: Keyword.get(opts, :model),
      prompt: Keyword.get(opts, :prompt, "ragex> ")
    }

    {:ok, state}
  end

  # The Yeesh executor calls IOServer.provide_input_and_wait/3 which does:
  #   GenServer.call(server, {:provide_input, input}, timeout)
  # We handle that same message shape here.

  @impl true
  def handle_call({:provide_input, input}, _from, state) do
    trimmed = String.trim(input)

    cond do
      trimmed in ["exit", "/quit", "/q"] ->
        {:reply, {"Goodbye!\r\n", :done}, state}

      trimmed == "" ->
        {:reply, {"", :waiting, state.prompt}, state}

      state.busy ->
        {:reply, {"A query is already running. Please wait.\r\n", :waiting, state.prompt}, state}

      true ->
        # Reply immediately so the LiveView unblocks; stream in the background
        spawn_streaming_task(trimmed, state)
        {:reply, {"", :waiting, ""}, %{state | busy: true}}
    end
  end

  # Fallback for IOServer.start_and_wait (called before first input)
  def handle_call(:start_and_wait, _from, state) do
    {:reply, {"", :waiting, state.prompt}, state}
  end

  # The executor may call IOServer.monitor_task -- no-op here
  def handle_call({:monitor_task, _pid}, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:stream_task_done, _ref, content}, state) do
    send(state.caller, {:ragex_stream_done, content})
    {:noreply, %{state | busy: false}}
  end

  def handle_info({:stream_task_error, _ref, reason}, state) do
    send(state.caller, {:ragex_task_error, "Chat error: #{inspect(reason)}"})
    {:noreply, %{state | busy: false}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # -- Private ----------------------------------------------------------------

  defp spawn_streaming_task(question, state) do
    caller = state.caller
    ref = make_ref()
    me = self()

    on_chunk = fn
      %{content: text} when is_binary(text) and text != "" ->
        send(caller, {:ragex_stream_chunk, text})

      _ ->
        :ok
    end

    chat_opts =
      [on_chunk: on_chunk]
      |> maybe_put(:provider, state.provider)
      |> maybe_put(:model, state.model)

    Task.start(fn ->
      case Core.stream_chat(state.session_id, question, chat_opts) do
        {:ok, result} ->
          send(me, {:stream_task_done, ref, result.content})

        {:error, reason} ->
          send(me, {:stream_task_error, ref, reason})
      end
    end)
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
