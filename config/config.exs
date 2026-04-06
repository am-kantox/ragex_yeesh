import Config

config :ragex_yeesh,
  generators: [timestamp_type: :utc_datetime]

# Working directory for all Ragex commands.
# Override at runtime with RAGEX_WORKING_DIR env var.
# When unset, defaults to File.cwd!() at application start.
# config :ragex_yeesh, :working_dir, "/path/to/project"

# Configure the endpoint
config :ragex_yeesh, RagexYeeshWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: RagexYeeshWeb.ErrorHTML, json: RagexYeeshWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: RagexYeesh.PubSub,
  live_view: [signing_salt: "RgxYsh42"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  ragex_yeesh: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{
      "NODE_PATH" => [
        Path.expand("../assets/node_modules", __DIR__),
        Path.expand("../deps", __DIR__),
        Mix.Project.build_path()
      ]
    }
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  ragex_yeesh: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
