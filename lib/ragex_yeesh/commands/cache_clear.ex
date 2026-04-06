if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.CacheClear do
    @moduledoc "Clear the embedding cache."
    use RagexYeesh.RagexCommand,
      task: "ragex.cache.clear",
      name: "cache-clear",
      description: "Clear the embedding cache"
  end
end
