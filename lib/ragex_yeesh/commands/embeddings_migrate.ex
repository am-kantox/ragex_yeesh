if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.EmbeddingsMigrate do
    @moduledoc "Migrate embeddings to a different model."
    use RagexYeesh.RagexCommand,
      task: "ragex.embeddings.migrate",
      name: "embeddings-migrate",
      description: "Migrate embeddings to a different model"
  end
end
