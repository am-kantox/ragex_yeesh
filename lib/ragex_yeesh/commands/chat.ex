if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.Chat do
    @moduledoc "Interactive codebase Q&A powered by RAG."
    use RagexYeesh.RagexCommand,
      task: "ragex.chat",
      name: "chat",
      description: "Interactive codebase Q&A powered by RAG",
      inject_path: true
  end
end
