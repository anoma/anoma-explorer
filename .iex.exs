# AnomaExplorer IEx Helpers
# Load with: iex -S mix or iex -S mix phx.server

alias AnomaExplorer.Repo
alias AnomaExplorer.Settings
alias AnomaExplorer.Indexer.GraphQL
alias AnomaExplorer.Indexer.Cache
alias AnomaExplorer.Indexer.Networks

import Ecto.Query

IO.puts("\n=== AnomaExplorer IEx Helpers ===\n")

defmodule H do
  @moduledoc "Helper functions for IEx exploration."

  alias AnomaExplorer.Indexer.GraphQL
  alias AnomaExplorer.Indexer.Cache
  alias AnomaExplorer.Indexer.Networks
  alias AnomaExplorer.Settings

  # ── GraphQL Queries ──────────────────────────────────────────────────

  @doc "Dashboard stats (cached 10s)"
  def stats(opts \\ []), do: GraphQL.get_stats(opts)

  @doc "List transactions"
  def txs(opts \\ [limit: 10]), do: GraphQL.list_transactions(opts)

  @doc "Get transaction by ID"
  def tx(id), do: GraphQL.get_transaction(id)

  @doc "List resources"
  def resources(opts \\ [limit: 10]), do: GraphQL.list_resources(opts)

  @doc "Get resource by ID"
  def resource(id), do: GraphQL.get_resource(id)

  @doc "List actions"
  def actions(opts \\ [limit: 10]), do: GraphQL.list_actions(opts)

  @doc "Get action by ID"
  def action(id), do: GraphQL.get_action(id)

  @doc "Run raw GraphQL query"
  def gql(query), do: GraphQL.execute_raw(query)

  # ── Network Info ─────────────────────────────────────────────────────

  @doc "Get network name for chain ID"
  def chain(id), do: Networks.name(id)

  @doc "List supported chains"
  def chains, do: Networks.list_chains()

  @doc "Block explorer URL for chain"
  def explorer(chain_id), do: Networks.explorer_url(chain_id)

  # ── Settings ─────────────────────────────────────────────────────────

  @doc "Get Envio GraphQL URL"
  def url, do: Settings.get_envio_url()

  @doc "Set Envio GraphQL URL"
  def url!(u), do: Settings.set_envio_url(u)

  @doc "List protocols"
  def protocols, do: Settings.list_protocols()

  @doc "List networks"
  def networks, do: Settings.list_networks()

  @doc "List contract addresses"
  def contracts(opts \\ []), do: Settings.list_contract_addresses(opts)

  # ── Cache ────────────────────────────────────────────────────────────

  @doc "Clear GraphQL cache"
  def clear_cache, do: Cache.clear()

  # ── Environment ──────────────────────────────────────────────────────

  @doc "Show environment config"
  def env do
    IO.puts("""

    Environment:
      ENVIO_GRAPHQL_URL: #{System.get_env("ENVIO_GRAPHQL_URL") || "(not set)"}
      DATABASE_URL:      #{if System.get_env("DATABASE_URL"), do: "(set)", else: "(not set)"}
      PHX_HOST:          #{System.get_env("PHX_HOST") || "localhost"}
      PORT:              #{System.get_env("PORT") || "4000"}
    """)
  end

  # ── Help ─────────────────────────────────────────────────────────────

  @doc "Print helper usage"
  def help do
    IO.puts("""

    AnomaExplorer IEx Helpers
    ═════════════════════════

    GraphQL Queries:
      H.stats()             - Dashboard statistics
      H.txs(limit: 10)      - List transactions
      H.tx(id)              - Get transaction by ID
      H.resources(limit: 10)- List resources
      H.resource(id)        - Get resource by ID
      H.actions(limit: 10)  - List actions
      H.action(id)          - Get action by ID
      H.gql(query)          - Raw GraphQL query

    Network Info:
      H.chains()            - List supported chains
      H.chain(id)           - Chain name for ID
      H.explorer(id)        - Block explorer URL

    Settings:
      H.url()               - Get Envio GraphQL URL
      H.url!(url)           - Set Envio GraphQL URL
      H.protocols()         - List protocols
      H.networks()          - List networks
      H.contracts()         - List contract addresses

    Other:
      H.clear_cache()       - Clear GraphQL cache
      H.env()               - Show environment config
    """)
  end
end

IO.puts("Type H.help() for available commands\n")
