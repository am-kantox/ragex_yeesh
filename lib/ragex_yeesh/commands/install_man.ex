if Code.ensure_loaded?(Mix) do
  defmodule RagexYeesh.Commands.InstallMan do
    @moduledoc "Install man pages for Ragex."
    use RagexYeesh.RagexCommand,
      task: "ragex.install_man",
      name: "install-man",
      description: "Install man pages for Ragex"
  end
end
