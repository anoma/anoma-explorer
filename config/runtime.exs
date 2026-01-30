import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/anoma_explorer start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :anoma_explorer, AnomaExplorerWeb.Endpoint, server: true
end

config :anoma_explorer, AnomaExplorerWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Envio Hyperindex GraphQL endpoint for indexed blockchain data
if envio_graphql_url = System.get_env("ENVIO_GRAPHQL_URL") do
  config :anoma_explorer, :envio_graphql_url, envio_graphql_url
end

# SSL verification for GraphQL client requests
# Set to "true" to enable certificate verification (recommended for production)
# Default: false (disabled for development convenience)
config :anoma_explorer, :ssl_verify, System.get_env("SSL_VERIFY", "false") == "true"

# Chain explorer API key for contract verification
# Etherscan V2 API uses a single key for all supported chains
if etherscan_api_key = System.get_env("ETHERSCAN_API_KEY") do
  config :anoma_explorer, :etherscan_api_key, etherscan_api_key
end

# Admin authorization for production settings
if admin_secret_key = System.get_env("ADMIN_SECRET_KEY") do
  config :anoma_explorer, :admin_secret_key, admin_secret_key
end

if admin_timeout = System.get_env("ADMIN_TIMEOUT_MINUTES") do
  config :anoma_explorer, :admin_timeout_minutes, String.to_integer(admin_timeout)
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :anoma_explorer, AnomaExplorer.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  # Build check_origin list - include configured host and common patterns
  check_origin =
    if host == "example.com" do
      # No PHX_HOST set - use permissive mode for the connection's host
      :conn
    else
      ["https://#{host}", "https://www.#{host}"]
    end

  # Force SSL/HTTPS redirect configuration
  # Default: enabled (configured in prod.exs with HSTS and health check exclusion)
  # Set FORCE_SSL=false to disable redirect (useful when TLS terminates at load balancer)
  #
  # IMPORTANT: The force_ssl config must match compile-time value exactly to avoid
  # Phoenix compile_env validation errors. The full config is in prod.exs.
  # Here we only override to `false` when explicitly disabled.
  force_ssl_disabled = System.get_env("FORCE_SSL") == "false"

  # Base endpoint config without force_ssl (uses compile-time value from prod.exs)
  endpoint_config = [
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    check_origin: check_origin,
    secret_key_base: secret_key_base
  ]

  # Only override force_ssl when explicitly disabled
  endpoint_config =
    if force_ssl_disabled do
      Keyword.put(endpoint_config, :force_ssl, false)
    else
      # Use compile-time value from prod.exs (with MFA tuple for exclude function)
      endpoint_config
    end

  config :anoma_explorer, AnomaExplorerWeb.Endpoint, endpoint_config

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :anoma_explorer, AnomaExplorerWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :anoma_explorer, AnomaExplorerWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
