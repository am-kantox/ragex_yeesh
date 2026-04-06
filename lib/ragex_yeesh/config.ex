defmodule RagexYeesh.Config do
  @moduledoc """
  Application-wide configuration for RagexYeesh.

  Provides access to the working directory that all Ragex commands
  operate on. The working directory is resolved once at application
  startup and remains fixed for the entire session.

  ## Resolution order

    1. `RAGEX_WORKING_DIR` environment variable
    2. `:ragex_yeesh, :working_dir` application config
    3. `File.cwd!()`

  The resolved path is expanded to an absolute path and stored in
  the application environment under `:ragex_yeesh, :working_dir`.
  """

  @doc """
  Returns the configured working directory (absolute path).

  This is the path that gets injected as `--path` into Ragex mix
  tasks that accept it.
  """
  @spec working_dir() :: String.t()
  def working_dir do
    Application.fetch_env!(:ragex_yeesh, :working_dir)
  end

  @doc """
  Resolves and persists the working directory at application boot.

  Called from `RagexYeesh.Application.start/2`. Reads the directory
  from the environment variable or config, expands it, validates
  that it exists, and stores the result in the application env.
  """
  @spec resolve_working_dir!() :: String.t()
  def resolve_working_dir! do
    dir =
      System.get_env("RAGEX_WORKING_DIR") ||
        Application.get_env(:ragex_yeesh, :working_dir) ||
        File.cwd!()

    expanded = Path.expand(dir)

    unless File.dir?(expanded) do
      raise """
      RagexYeesh working directory does not exist: #{expanded}

      Set a valid path via:
        - RAGEX_WORKING_DIR environment variable
        - config :ragex_yeesh, :working_dir, "/path/to/project"
      """
    end

    Application.put_env(:ragex_yeesh, :working_dir, expanded)
    expanded
  end
end
