import Config

config :ragex_yeesh, RagexYeeshWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Do not print debug messages in production
config :logger, level: :info

# Enable the built-in `mix` command in the Yeesh terminal
config :yeesh, enable_mix_command: true
