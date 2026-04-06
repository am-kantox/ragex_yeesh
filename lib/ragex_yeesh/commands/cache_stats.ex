if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.CacheStats do
    @moduledoc "View embedding cache statistics."
    use RagexYeesh.RagexCommand,
      task: "ragex.cache.stats",
      name: "cache-stats",
      description: "View embedding cache statistics"
  end
end
