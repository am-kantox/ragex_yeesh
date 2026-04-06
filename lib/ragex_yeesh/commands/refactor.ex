if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.Refactor do
    @moduledoc "Interactive refactoring wizard."
    use RagexYeesh.RagexCommand,
      task: "ragex.refactor",
      name: "refactor",
      description: "Interactive refactoring wizard (rename, extract, inline, ...)"
  end
end
