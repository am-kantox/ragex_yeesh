if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.RagexCommand do
    @moduledoc """
    Generates a `Yeesh.Command` module that wraps a Ragex Mix task.

    Works like `Yeesh.MixCommand` but adds several features specific
    to the RagexYeesh application:

    1. **Runtime `--path` injection** -- when `inject_path: true`,
       the configured working directory (see `RagexYeesh.Config`) is
       automatically prepended as `--path <dir>` to every invocation.
       Any `--path` / `-p` flags supplied by the user are silently
       stripped so the application-level setting always wins.

    2. **Rich help output** -- `usage/0` returns the full `@moduledoc`
       of the underlying Mix task module rendered through `Marcli` so
       `help <command>` in the Yeesh terminal shows a properly
       formatted option reference.

    3. **Async execution** -- when `async: true`, the Mix task runs
       in a background `Task` and a short "Running ..." message is
       returned immediately.  The LiveView process stays responsive
       to WebSocket heartbeats.  When the task finishes the result
       is sent to the LiveView via `send/2` and pushed to the
       terminal from `handle_info`.

    4. **Logger guard** -- saves and restores the global Logger level
       around task execution (some Ragex tasks set it to `:emergency`).

    ## Options

      * `:task` (required) -- the Mix task name
      * `:name` (required) -- the command name in the Yeesh terminal
      * `:description` -- short description for `help` output
      * `:inject_path` -- prepend `--path <working_dir>` (default: `false`)
      * `:async` -- run in a background Task (default: `false`)
      * `:default_args` -- additional default arguments (default: `[]`)
    """

    @doc false
    defmacro __using__(opts) do
      task = Keyword.fetch!(opts, :task)
      cmd_name = Keyword.fetch!(opts, :name)
      desc = Keyword.get(opts, :description, "Run mix #{task}")
      inject_path = Keyword.get(opts, :inject_path, false)
      async = Keyword.get(opts, :async, false)
      default_args = Keyword.get(opts, :default_args, [])

      quote do
        @behaviour Yeesh.Command

        alias Yeesh.{MixRunner, Output}

        @mix_task unquote(task)
        @cmd_name unquote(cmd_name)
        @cmd_desc unquote(desc)
        @inject_path unquote(inject_path)
        @async unquote(async)
        @default_args unquote(default_args)

        @impl true
        def name, do: @cmd_name

        @impl true
        def description, do: @cmd_desc

        @impl true
        def usage do
          base = "#{@cmd_name} [args...]"

          case Mix.Task.get(@mix_task) do
            nil ->
              base

            task_module ->
              case Code.fetch_docs(task_module) do
                {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} ->
                  Marcli.render(moduledoc, newline: "\r\n")

                _ ->
                  base
              end
          end
        end

        @impl true
        def execute(args, session) do
          # Belt-and-suspenders: ragex is started in start_phase
          # but ensure it is running in case start_phase was skipped.
          Application.put_env(:ragex, :start_server, false)
          Application.ensure_all_started(:ragex)

          full_args =
            args
            |> strip_path_args()
            |> then(&(@default_args ++ &1))
            |> maybe_inject_path()

          if @async do
            run_async(full_args, session)
          else
            run_sync(full_args, session)
          end
        end

        # -- Async path (long-running tasks) --------------------------------
        # Returns immediately so the LiveView can keep processing
        # heartbeats.  The result is delivered to the LiveView via
        # send/2 and handled in TerminalLive.handle_info/2.

        defp run_async(full_args, session) do
          caller = self()
          prev_log_level = Logger.level()
          mix_task = @mix_task

          Task.start(fn ->
            # :erlang.display bypasses Logger suppression and IO group leader
            :erlang.display({:ragex_async, :start, mix_task, self()})

            result =
              try do
                case MixRunner.run(mix_task, full_args, timeout: :infinity) do
                  {:completed, output} ->
                    :erlang.display({:ragex_async, :completed, byte_size(output)})
                    {:ok, output}

                  {:interactive, _, _, output, _} ->
                    :erlang.display({:ragex_async, :interactive, byte_size(output)})
                    {:ok, output}

                  {:error, reason} ->
                    :erlang.display({:ragex_async, :error, reason})
                    {:error, to_string(reason)}
                end
              rescue
                e ->
                  :erlang.display({:ragex_async, :rescue, Exception.message(e)})
                  {:error, Exception.message(e)}
              catch
                :exit, reason ->
                  :erlang.display({:ragex_async, :exit, reason})
                  {:error, "task exited: #{inspect(reason)}"}
              after
                Logger.configure(level: prev_log_level)
              end

            :erlang.display({:ragex_async, :sending, elem(result, 0), Process.alive?(caller)})

            case result do
              {:ok, output} -> send(caller, {:ragex_task_result, output})
              {:error, reason} -> send(caller, {:ragex_task_error, reason})
            end
          end)

          {:ok, "Running #{@cmd_name} ...\r\n", session}
        end

        # -- Sync path (quick tasks) ----------------------------------------

        defp run_sync(full_args, session) do
          prev_log_level = Logger.level()

          result =
            try do
              case MixRunner.run(@mix_task, full_args, timeout: :infinity) do
                {:completed, output} ->
                  {:ok, output, session}

                {:interactive, io_server, task_pid, output, prompt} ->
                  new_session = %{
                    session
                    | mode: :mix_task,
                      context:
                        Map.merge(session.context, %{
                          mix_io_server: io_server,
                          mix_task_pid: task_pid,
                          mix_prompt: prompt,
                          mix_original_shell: Mix.shell()
                        })
                  }

                  {:ok, output, new_session}

                {:error, reason} ->
                  {:error, to_string(reason), session}
              end
            rescue
              e ->
                {:error, Exception.message(e), session}
            catch
              :exit, reason ->
                {:error, "task exited: #{inspect(reason)}", session}
            end

          Logger.configure(level: prev_log_level)
          result
        end

        # -- Shared helpers -------------------------------------------------

        defp strip_path_args(args) do
          if @inject_path do
            do_strip_path(args, [])
          else
            args
          end
        end

        defp do_strip_path([], acc), do: Enum.reverse(acc)

        defp do_strip_path(["--path", _value | rest], acc),
          do: do_strip_path(rest, acc)

        defp do_strip_path(["-p", _value | rest], acc),
          do: do_strip_path(rest, acc)

        defp do_strip_path([<<"--path=", _rest::binary>> | rest], acc),
          do: do_strip_path(rest, acc)

        defp do_strip_path([head | rest], acc),
          do: do_strip_path(rest, [head | acc])

        defp maybe_inject_path(args) do
          if @inject_path do
            ["--path", RagexYeesh.Config.working_dir() | args]
          else
            args
          end
        end
      end
    end
  end
end
