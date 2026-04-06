if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.AiCacheClear do
    @moduledoc "Clear the AI response cache."
    use RagexYeesh.RagexCommand,
      task: "ragex.ai.cache.clear",
      name: "ai-cache-clear",
      description: "Clear the AI response cache"
  end
end
