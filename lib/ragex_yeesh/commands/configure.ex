if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.Configure do
    @moduledoc "Configuration wizard for Ragex settings."
    use RagexYeesh.RagexCommand,
      task: "ragex.configure",
      name: "configure",
      description: "Configuration wizard (models, AI providers, analysis options)"
  end
end
