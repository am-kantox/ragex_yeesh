if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.Completions do
    @moduledoc "Install shell completion scripts."
    use RagexYeesh.RagexCommand,
      task: "ragex.completions",
      name: "completions",
      description: "Install shell completion scripts (bash, zsh, fish)"
  end
end
