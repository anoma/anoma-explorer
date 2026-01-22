defmodule AnomaExplorerWeb.TransactionsLive do
  @moduledoc """
  LiveView for listing transactions from the Envio indexer.
  """
  use AnomaExplorerWeb, :live_view

  alias AnomaExplorerWeb.Layouts
  alias AnomaExplorer.Indexer.GraphQL
  alias AnomaExplorer.Indexer.Client
  alias AnomaExplorer.Indexer.Networks

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: send(self(), :load_data)

    {:ok,
     socket
     |> assign(:page_title, "Transactions")
     |> assign(:transactions, [])
     |> assign(:loading, true)
     |> assign(:error, nil)
     |> assign(:page, 0)
     |> assign(:has_more, false)
     |> assign(:configured, Client.configured?())}
  end

  @impl true
  def handle_info(:load_data, socket) do
    socket = load_transactions(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    socket =
      socket
      |> assign(:page, socket.assigns.page + 1)
      |> assign(:loading, true)
      |> load_transactions()

    {:noreply, socket}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    socket =
      socket
      |> assign(:page, max(0, socket.assigns.page - 1))
      |> assign(:loading, true)
      |> load_transactions()

    {:noreply, socket}
  end

  defp load_transactions(socket) do
    if not Client.configured?() do
      socket
      |> assign(:configured, false)
      |> assign(:loading, false)
    else
      offset = socket.assigns.page * @page_size

      case GraphQL.list_transactions(limit: @page_size + 1, offset: offset) do
        {:ok, transactions} ->
          has_more = length(transactions) > @page_size
          display_txs = Enum.take(transactions, @page_size)

          socket
          |> assign(:transactions, display_txs)
          |> assign(:has_more, has_more)
          |> assign(:loading, false)
          |> assign(:error, nil)
          |> assign(:configured, true)

        {:error, reason} ->
          socket
          |> assign(:loading, false)
          |> assign(:error, format_error(reason))
      end
    end
  end

  defp format_error(:not_configured), do: "Indexer endpoint not configured"
  defp format_error({:connection_error, _}), do: "Failed to connect to indexer"
  defp format_error(reason), do: "Error: #{inspect(reason)}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path="/transactions">
      <div class="page-header">
        <div>
          <h1 class="page-title">Transactions</h1>
          <p class="text-sm text-base-content/70 mt-1">
            All indexed Anoma transactions
          </p>
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

        <div class="stat-card">
          <%= if @loading and @transactions == [] do %>
            <.loading_skeleton />
          <% else %>
            <.transactions_table transactions={@transactions} />
          <% end %>

          <.pagination page={@page} has_more={@has_more} loading={@loading} />
        </div>
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
          <h2 class="text-lg font-semibold text-base-content">Indexer Not Configured</h2>
          <p class="text-sm text-base-content/70">
            Configure the Envio GraphQL endpoint to view transactions.
          </p>
          <a href="/settings/indexer" class="btn btn-primary btn-sm mt-3">
            Configure Indexer
          </a>
        </div>
      </div>
    </div>
    """
  end

  defp loading_skeleton(assigns) do
    ~H"""
    <div class="animate-pulse space-y-3">
      <%= for _ <- 1..5 do %>
        <div class="h-12 bg-base-300 rounded"></div>
      <% end %>
    </div>
    """
  end

  defp transactions_table(assigns) do
    ~H"""
    <%= if @transactions == [] do %>
      <div class="text-center py-12 text-base-content/50">
        <.icon name="hero-inbox" class="w-12 h-12 mx-auto mb-2 opacity-50" />
        <p>No transactions found</p>
      </div>
    <% else %>
      <div class="overflow-x-auto">
        <table class="data-table w-full">
          <thead>
            <tr>
              <th>Tx Hash</th>
              <th>Network</th>
              <th>Block</th>
              <th>Resources</th>
              <th class="hidden lg:table-cell">Time</th>
            </tr>
          </thead>
          <tbody>
            <%= for tx <- @transactions do %>
              <% tags = tx["tags"] || [] %>
              <% consumed = div(length(tags), 2) %>
              <% created = length(tags) - consumed %>
              <tr class="hover:bg-base-200/50 cursor-pointer" phx-click={JS.navigate("/transactions/#{tx["id"]}")}>
                <td>
                  <span class="hash-display"><%= truncate_hash(tx["txHash"]) %></span>
                </td>
                <td>
                  <span class="badge badge-outline badge-sm" title={"Chain ID: #{tx["chainId"]}"}>
                    <%= Networks.short_name(tx["chainId"]) %>
                  </span>
                </td>
                <td>
                  <span class="font-mono text-sm"><%= tx["blockNumber"] %></span>
                </td>
                <td>
                  <span class="badge badge-error badge-sm" title="Consumed"><%= consumed %></span>
                  <span class="badge badge-success badge-sm" title="Created"><%= created %></span>
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
    """
  end

  defp pagination(assigns) do
    ~H"""
    <div class="flex items-center justify-between mt-4 pt-4 border-t border-base-300">
      <button
        phx-click="prev_page"
        disabled={@page == 0 || @loading}
        class="btn btn-ghost btn-sm"
      >
        <.icon name="hero-chevron-left" class="w-4 h-4" />
        Previous
      </button>
      <span class="text-sm text-base-content/60">
        Page <%= @page + 1 %>
      </span>
      <button
        phx-click="next_page"
        disabled={not @has_more || @loading}
        class="btn btn-ghost btn-sm"
      >
        Next
        <.icon name="hero-chevron-right" class="w-4 h-4" />
      </button>
    </div>
    """
  end

  defp truncate_hash(nil), do: "-"

  defp truncate_hash(hash) when byte_size(hash) > 16 do
    String.slice(hash, 0, 10) <> "..." <> String.slice(hash, -6, 6)
  end

  defp truncate_hash(hash), do: hash

  defp format_timestamp(nil), do: "-"

  defp format_timestamp(ts) when is_integer(ts) do
    case DateTime.from_unix(ts) do
      {:ok, dt} -> format_relative(dt)
      _ -> "-"
    end
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
