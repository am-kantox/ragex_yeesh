import Config

config :ragex_yeesh, RagexYeeshWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Q8rT3xVn5hLp2mK7jF0cB9dA6wGuEiYlZs4aOfCbRnMtSyDqHxWePzJkNoI1uXvr",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix,
  sort_verified_routes_query_params: true
