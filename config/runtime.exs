import Config

if working_dir = System.get_env("RAGEX_WORKING_DIR") do
  config :ragex_yeesh, :working_dir, working_dir
end

# Wire AI provider API keys from environment variables into Ragex config.
# Ragex reads keys from :ragex, :ai_keys, not from System.get_env.
ai_keys =
  [
    System.get_env("DEEPSEEK_API_KEY") && {:deepseek_r1, System.get_env("DEEPSEEK_API_KEY")},
    System.get_env("OPENAI_API_KEY") && {:openai, System.get_env("OPENAI_API_KEY")},
    System.get_env("ANTHROPIC_API_KEY") && {:anthropic, System.get_env("ANTHROPIC_API_KEY")}
  ]
  |> Enum.reject(&is_nil/1)

if ai_keys != [] do
  config :ragex, :ai_keys, ai_keys
end

ai_providers =
  [
    System.get_env("DEEPSEEK_API_KEY") &&
      {:deepseek_r1,
       [
         endpoint: "https://api.deepseek.com",
         model: "deepseek-chat"
       ]},
    System.get_env("OPENAI_API_KEY") &&
      {:openai,
       [
         endpoint: "https://api.openai.com",
         model: System.get_env("OPENAI_MODEL", "gpt-4o")
       ]},
    System.get_env("ANTHROPIC_API_KEY") &&
      {:anthropic,
       [
         endpoint: "https://api.anthropic.com",
         model: System.get_env("ANTHROPIC_MODEL", "claude-sonnet-4-20250514")
       ]}
  ]
  |> Enum.reject(&is_nil/1)

if ai_providers != [] do
  config :ragex, :ai_providers, ai_providers
end

if System.get_env("PHX_SERVER") do
  config :ragex_yeesh, RagexYeeshWeb.Endpoint, server: true
end

config :ragex_yeesh, RagexYeeshWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))],
  # Allow iframe embedding from Oeditus host
  check_origin: false

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
