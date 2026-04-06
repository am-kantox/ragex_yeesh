defmodule RagexYeeshWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :ragex_yeesh

  @session_options [
    store: :cookie,
    key: "_ragex_yeesh_key",
    signing_salt: "RgxYshSl",
    same_site: "Lax"
  ]

  # Long timeout to match the client heartbeat: Ragex analysis tasks
  # block the LiveView process for several minutes.
  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options], timeout: 660_000],
    longpoll: [connect_info: [session: @session_options]]
  )

  plug(Plug.Static,
    at: "/",
    from: :ragex_yeesh,
    gzip: not code_reloading?,
    only: RagexYeeshWeb.static_paths(),
    raise_on_missing_only: code_reloading?
  )

  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(RagexYeeshWeb.Router)
end
