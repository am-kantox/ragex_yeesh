if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.Analyze do
    @moduledoc "Analyze source files and build the knowledge graph."
    use RagexYeesh.RagexCommand,
      task: "ragex.analyze",
      name: "analyze",
      description: "Analyze source files and build the knowledge graph",
      inject_path: true,
      async: true
  end
end
