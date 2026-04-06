if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.AiUsageStats do
    @moduledoc "View AI provider usage statistics and costs."
    use RagexYeesh.RagexCommand,
      task: "ragex.ai.usage.stats",
      name: "ai-usage",
      description: "View AI provider usage statistics and costs"
  end
end
