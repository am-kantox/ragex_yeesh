import Config

if working_dir = System.get_env("RAGEX_WORKING_DIR") do
  config :ragex_yeesh, :working_dir, working_dir
end

# Wire the DEEPSEEK_API_KEY env var into the ragex AI provider config.
# Ragex reads keys from :ragex, :ai_keys, not from System.get_env.
if deepseek_key = System.get_env("DEEPSEEK_API_KEY") do
  config :ragex, :ai_keys, deepseek_r1: deepseek_key

  config :ragex, :ai_providers,
    deepseek_r1: [
      endpoint: "https://api.deepseek.com",
      model: "deepseek-chat"
    ]
end

if System.get_env("PHX_SERVER") do
  config :ragex_yeesh, RagexYeeshWeb.Endpoint, server: true
end

config :ragex_yeesh, RagexYeeshWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"

  config :ragex_yeesh, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :ragex_yeesh, RagexYeeshWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base
end
