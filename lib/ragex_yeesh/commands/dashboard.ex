if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.Dashboard do
    @moduledoc "Live monitoring dashboard for Ragex stats."
    use RagexYeesh.RagexCommand,
      task: "ragex.dashboard",
      name: "dashboard",
      description: "Live monitoring dashboard (graph, embeddings, cache, AI usage)"
  end
end
