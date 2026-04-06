if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.ModelsDownload do
    @moduledoc "Pre-download ML models for offline use."
    use RagexYeesh.RagexCommand,
      task: "ragex.models.download",
      name: "models-download",
      description: "Pre-download ML models for offline use"
  end
end
