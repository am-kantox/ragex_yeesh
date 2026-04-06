if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.AiCacheStats do
    @moduledoc "View AI response cache statistics."
    use RagexYeesh.RagexCommand,
      task: "ragex.ai.cache.stats",
      name: "ai-cache-stats",
      description: "View AI response cache statistics"
  end
end
