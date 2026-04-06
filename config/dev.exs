import Config

# Bind to all interfaces so the app is accessible from outside Docker
config :ragex_yeesh, RagexYeeshWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "VUDTOu2AEnmVT9llWIJo2EOmb/tMbDbwYOW7Er3hnx0wWCH1nR4XKr3GzgmE8rBfk7Fj8RqXw2NpYmT5vL3cH9dA6sGnBx4eUiOlZr1aJfCbKmVtSyDhEwPqMzWoI0u",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:ragex_yeesh, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:ragex_yeesh, ~w(--watch)]}
  ]

# Reload browser tabs when matching files change.
config :ragex_yeesh, RagexYeeshWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/ragex_yeesh_web/router\.ex$",
      ~r"lib/ragex_yeesh_web/(controllers|live|components)/.*\.(ex|heex)$"
    ]
  ]

config :ragex_yeesh, dev_routes: true

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# Enable the built-in `mix` command in the Yeesh terminal
config :yeesh, enable_mix_command: true

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true
