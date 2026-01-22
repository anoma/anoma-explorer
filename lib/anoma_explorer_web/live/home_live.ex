defmodule AnomaExplorerWeb.HomeLive do
  @moduledoc """
  Dashboard LiveView showing stats and recent transactions from the Envio indexer.
  """
  use AnomaExplorerWeb, :live_view

  alias AnomaExplorerWeb.Layouts
  alias AnomaExplorer.Indexer.GraphQL
  alias AnomaExplorer.Indexer.Client

  @refresh_interval 30_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      send(self(), :load_data)
      :timer.send_interval(@refresh_interval, self(), :refresh)
    end

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:stats, nil)
     |> assign(:transactions, [])
     |> assign(:loading, true)
     |> assign(:error, nil)
     |> assign(:configured, Client.configured?())
     |> assign(:last_updated, nil)}
  end

  @impl true
  def handle_info(:load_data, socket) do
    socket = load_dashboard_data(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    if socket.assigns.configured do
      socket = load_dashboard_data(socket)
      {:noreply, socket}
    else
      {:noreply, assign(socket, :configured, Client.configured?())}
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    socket =
      socket
      |> assign(:loading, true)
      |> load_dashboard_data()

    {:noreply, socket}
  end

  defp load_dashboard_data(socket) do
    if not Client.configured?() do
      socket
      |> assign(:configured, false)
      |> assign(:loading, false)
    else
      stats_result = GraphQL.get_stats()
      txs_result = GraphQL.list_transactions(limit: 10)

      case {stats_result, txs_result} do
        {{:ok, stats}, {:ok, transactions}} ->
          socket
          |> assign(:stats, stats)
          |> assign(:transactions, transactions)
          |> assign(:loading, false)
          |> assign(:error, nil)
          |> assign(:configured, true)
          |> assign(:last_updated, DateTime.utc_now())

        {{:error, reason}, _} ->
          socket
          |> assign(:loading, false)
          |> assign(:error, format_error(reason))

        {_, {:error, reason}} ->
          socket
          |> assign(:loading, false)
          |> assign(:error, format_error(reason))
      end
    end
  end

  defp format_error(:not_configured), do: "Indexer endpoint not configured"
  defp format_error({:connection_error, _}), do: "Failed to connect to indexer"
  defp format_error({:http_error, status, _}), do: "HTTP error: #{status}"
  defp format_error({:graphql_error, errors}), do: "GraphQL error: #{inspect(errors)}"
  defp format_error(reason), do: "Error: #{inspect(reason)}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path="/">
      <div class="page-header">
        <div>
          <h1 class="page-title">Dashboard</h1>
          <p class="text-sm text-base-content/70 mt-1">
            Anoma Protocol Activity Overview
          </p>
        </div>
        <div class="flex items-center gap-2">
          <%= if @last_updated do %>
            <span class="text-xs text-base-content/50">
              Updated <%= format_time(@last_updated) %>
            </span>
          <% end %>
          <button phx-click="refresh" class="btn btn-ghost btn-sm" disabled={@loading}>
            <.icon name="hero-arrow-path" class={["w-4 h-4", @loading && "animate-spin"]} />
          </button>
        </div>
      </div>

      <%= if not @configured do %>
        <.not_configured_message />
      <% else %>
        <%= if @error do %>
          <div class="alert alert-error mb-6">
            <.icon name="hero-exclamation-triangle" class="h-5 w-5" />
            <span><%= @error %></span>
          </div>
        <% end %>

        <%= if @loading and is_nil(@stats) do %>
          <.loading_skeleton />
        <% else %>
          <.stats_grid stats={@stats} />
          <.recent_transactions transactions={@transactions} loading={@loading} />
        <% end %>
      <% end %>
    </Layouts.app>
    """
  end

  defp not_configured_message(assigns) do
    ~H"""
    <div class="stat-card">
      <div class="flex items-center gap-4">
        <div class="w-14 h-14 rounded-xl bg-warning/10 flex items-center justify-center">
          <.icon name="hero-exclamation-triangle" class="w-7 h-7 text-warning" />
        </div>
        <div class="flex-1">
          <h2 class="text-lg font-semibold text-base-content">
            Indexer Not Configured
          </h2>
          <p class="text-sm text-base-content/70">
            Configure the Envio GraphQL endpoint to view indexed data.
          </p>
          <a href="/settings/indexer" class="btn btn-primary btn-sm mt-3">
            <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
            Configure Indexer
          </a>
        </div>
      </div>
    </div>
    """
  end

  defp loading_skeleton(assigns) do
    ~H"""
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
      <%= for _ <- 1..4 do %>
        <div class="stat-card animate-pulse">
          <div class="h-4 bg-base-300 rounded w-20 mb-2"></div>
          <div class="h-8 bg-base-300 rounded w-16"></div>
        </div>
      <% end %>
    </div>
    """
  end

  defp stats_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 mb-6">
      <.stat_card
        label="Transactions"
        value={@stats.transactions}
        icon="hero-document-text"
        color="primary"
      />
      <.stat_card
        label="Resources"
        value={@stats.resources}
        icon="hero-cube"
        color="secondary"
      />
      <.stat_card
        label="Consumed"
        value={@stats.consumed}
        icon="hero-arrow-right-start-on-rectangle"
        color="error"
      />
      <.stat_card
        label="Created"
        value={@stats.created}
        icon="hero-plus-circle"
        color="success"
      />
      <.stat_card
        label="Actions"
        value={@stats.actions}
        icon="hero-bolt"
        color="warning"
      />
      <.stat_card
        label="Tree Roots"
        value={@stats.commitment_roots}
        icon="hero-server-stack"
        color="info"
      />
    </div>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="stat-card">
      <div class="flex items-center gap-2 mb-1">
        <.icon name={@icon} class={"w-4 h-4 text-#{@color}"} />
        <span class="text-xs text-base-content/60 uppercase tracking-wide"><%= @label %></span>
      </div>
      <div class="text-2xl font-bold text-base-content">
        <%= format_number(@value) %>
      </div>
    </div>
    """
  end

  defp recent_transactions(assigns) do
    ~H"""
    <div class="stat-card">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold">Recent Transactions</h2>
        <a href="/transactions" class="btn btn-ghost btn-sm">
          View All
          <.icon name="hero-arrow-right" class="w-4 h-4" />
        </a>
      </div>

      <%= if @transactions == [] do %>
        <div class="text-center py-8 text-base-content/50">
          <.icon name="hero-inbox" class="w-12 h-12 mx-auto mb-2 opacity-50" />
          <p>No transactions found</p>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="data-table w-full">
            <thead>
              <tr>
                <th>Tx Hash</th>
                <th>Block</th>
                <th>Tags</th>
                <th>Logic Refs</th>
                <th class="hidden lg:table-cell">Time</th>
              </tr>
            </thead>
            <tbody>
              <%= for tx <- @transactions do %>
                <tr>
                  <td>
                    <a href={"/transactions/#{tx["id"]}"} class="hash-display hover:text-primary">
                      <%= truncate_hash(tx["txHash"]) %>
                    </a>
                  </td>
                  <td>
                    <span class="font-mono text-sm"><%= tx["blockNumber"] %></span>
                  </td>
                  <td>
                    <span class="badge badge-ghost"><%= length(tx["tags"] || []) %></span>
                  </td>
                  <td>
                    <span class="badge badge-ghost"><%= length(tx["logicRefs"] || []) %></span>
                  </td>
                  <td class="hidden lg:table-cell text-base-content/60 text-sm">
                    <%= format_timestamp(tx["timestamp"]) %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp truncate_hash(nil), do: "-"

  defp truncate_hash(hash) when byte_size(hash) > 16 do
    String.slice(hash, 0, 10) <> "..." <> String.slice(hash, -6, 6)
  end

  defp truncate_hash(hash), do: hash

  defp format_number(nil), do: "-"
  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp format_number(n), do: Integer.to_string(n)

  defp format_timestamp(nil), do: "-"

  defp format_timestamp(ts) when is_integer(ts) do
    case DateTime.from_unix(ts) do
      {:ok, dt} -> format_relative(dt)
      _ -> "-"
    end
  end

  defp format_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M:%S")
  end

  defp format_relative(%DateTime{} = dt) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, dt, :second)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end
end
