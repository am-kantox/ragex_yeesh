if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.CacheRefresh do
    @moduledoc "Refresh the embedding cache incrementally."
    use RagexYeesh.RagexCommand,
      task: "ragex.cache.refresh",
      name: "cache-refresh",
      description: "Refresh the embedding cache (incremental or full)",
      inject_path: true,
      async: true
  end
end
