defmodule AnomaExplorerWeb.AnalyticsLive do
  @moduledoc """
  LiveView for displaying analytics dashboard.

  Shows activity statistics, charts, and trends.
  """
  use AnomaExplorerWeb, :live_view

  alias AnomaExplorer.Analytics
  alias AnomaExplorer.Config

  @default_days 30

  @impl true
  def mount(_params, _session, socket) do
    days = @default_days

    socket =
      socket
      |> assign(:page_title, "Analytics")
      |> assign(:days, days)
      |> assign(:selected_network, nil)
      |> load_analytics()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    days = parse_days(params["days"])
    network = params["network"]

    socket =
      socket
      |> assign(:days, days)
      |> assign(:selected_network, network)
      |> load_analytics()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_days", %{"days" => days}, socket) do
    params = build_params(days, socket.assigns.selected_network)
    {:noreply, push_patch(socket, to: ~p"/analytics?#{params}")}
  end

  @impl true
  def handle_event("change_network", %{"network" => network}, socket) do
    network = if network == "", do: nil, else: network
    params = build_params(socket.assigns.days, network)
    {:noreply, push_patch(socket, to: ~p"/analytics?#{params}")}
  end

  defp load_analytics(socket) do
    days = socket.assigns.days
    network = socket.assigns.selected_network

    opts =
      [days: days]
      |> maybe_add_network(network)

    socket
    |> assign(:summary, Analytics.summary_stats(opts))
    |> assign(:daily_counts, Analytics.daily_counts(opts))
    |> assign(:by_kind, Analytics.activity_by_kind(opts))
    |> assign(:by_network, Analytics.activity_by_network(days: days))
    |> assign(:networks, Config.supported_networks())
  end

  defp maybe_add_network(opts, nil), do: opts
  defp maybe_add_network(opts, network), do: Keyword.put(opts, :network, network)

  defp parse_days(nil), do: @default_days

  defp parse_days(days) when is_binary(days) do
    case Integer.parse(days) do
      {n, _} when n > 0 and n <= 365 -> n
      _ -> @default_days
    end
  end

  defp build_params(days, network) do
    []
    |> then(fn p -> if days != @default_days, do: [{"days", days} | p], else: p end)
    |> then(fn p -> if network, do: [{"network", network} | p], else: p end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path="/analytics">
      <!-- Page Header -->
      <div class="page-header">
        <div>
          <h1 class="page-title">Analytics</h1>
          <p class="text-sm text-base-content/60 mt-1">
            Activity statistics and trends
          </p>
        </div>

        <div class="flex items-center gap-3">
          <form phx-change="change_network">
            <select name="network" class="filter-select">
              <option value="">All Networks</option>
              <%= for network <- @networks do %>
                <option value={network} selected={@selected_network == network}>
                  {network}
                </option>
              <% end %>
            </select>
          </form>

          <form phx-change="change_days">
            <select name="days" class="filter-select">
              <option value="7" selected={@days == 7}>7 days</option>
              <option value="14" selected={@days == 14}>14 days</option>
              <option value="30" selected={@days == 30}>30 days</option>
              <option value="90" selected={@days == 90}>90 days</option>
            </select>
          </form>
        </div>
      </div>

      <!-- Stats Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div class="stat-card">
          <div class="flex items-center justify-between">
            <div>
              <p class="stat-card-label">Total Activities</p>
              <p class="stat-card-value">{format_number(@summary.total_count)}</p>
            </div>
            <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
              <.icon name="hero-queue-list" class="w-6 h-6 text-primary" />
            </div>
          </div>
        </div>

        <div class="stat-card">
          <div class="flex items-center justify-between">
            <div>
              <p class="stat-card-label">Active Networks</p>
              <p class="stat-card-value">{@summary.networks_active}</p>
            </div>
            <div class="w-12 h-12 rounded-xl bg-secondary/10 flex items-center justify-center">
              <.icon name="hero-globe-alt" class="w-6 h-6 text-secondary" />
            </div>
          </div>
        </div>

        <div class="stat-card">
          <div class="flex items-center justify-between">
            <div>
              <p class="stat-card-label">Event Types</p>
              <p class="stat-card-value">{@summary.kinds_used}</p>
            </div>
            <div class="w-12 h-12 rounded-xl bg-accent/10 flex items-center justify-center">
              <.icon name="hero-tag" class="w-6 h-6 text-accent" />
            </div>
          </div>
        </div>

        <div class="stat-card">
          <div class="flex items-center justify-between">
            <div>
              <p class="stat-card-label">Avg per Day</p>
              <p class="stat-card-value">{Float.round(@summary.avg_per_day, 1)}</p>
            </div>
            <div class="w-12 h-12 rounded-xl bg-info/10 flex items-center justify-center">
              <.icon name="hero-arrow-trending-up" class="w-6 h-6 text-info" />
            </div>
          </div>
        </div>
      </div>

      <!-- Charts Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <!-- Daily Activity Chart -->
        <div class="stat-card">
          <h3 class="text-lg font-semibold text-base-content mb-6">Daily Activity</h3>
          <.bar_chart data={@daily_counts} />
        </div>

        <!-- Activity by Type -->
        <div class="stat-card">
          <h3 class="text-lg font-semibold text-base-content mb-6">Activity by Type</h3>
          <.horizontal_bar_chart data={@by_kind} color="success" />
        </div>
      </div>

      <!-- Network Distribution -->
      <div class="stat-card">
        <h3 class="text-lg font-semibold text-base-content mb-6">Activity by Network</h3>
        <.horizontal_bar_chart data={@by_network} color="primary" />
      </div>
    </Layouts.app>
    """
  end

  defp format_number(num) when num >= 1_000_000 do
    "#{Float.round(num / 1_000_000, 1)}M"
  end

  defp format_number(num) when num >= 1_000 do
    "#{Float.round(num / 1_000, 1)}K"
  end

  defp format_number(num), do: "#{num}"

  # Simple text-based bar chart (CSS-based for simplicity)
  defp bar_chart(assigns) do
    max_count = assigns.data |> Enum.map(& &1.count) |> Enum.max(fn -> 1 end)
    assigns = assign(assigns, :max_count, max_count)

    ~H"""
    <div class="space-y-1">
      <%= if Enum.empty?(@data) do %>
        <div class="py-8 text-center">
          <p class="text-base-content/40 text-sm">No data available</p>
        </div>
      <% else %>
        <div class="flex flex-col gap-1">
          <%= for item <- @data do %>
            <div class="flex items-center gap-3 text-xs group">
              <span class="w-12 text-base-content/50 text-right font-mono">
                {format_date(item.date)}
              </span>
              <div class="flex-1 h-6 bg-base-300 rounded overflow-hidden">
                <div
                  class="chart-bar h-full flex items-center justify-end pr-2"
                  style={"width: #{bar_width(item.count, @max_count)}%"}
                >
                  <%= if item.count > 0 do %>
                    <span class="text-xs font-medium text-primary-content opacity-0 group-hover:opacity-100 transition-opacity">
                      {item.count}
                    </span>
                  <% end %>
                </div>
              </div>
              <span class="w-8 text-right text-base-content/70 font-mono">{item.count}</span>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Horizontal bar chart for categorical data
  attr :data, :map, required: true
  attr :color, :string, default: "primary"

  defp horizontal_bar_chart(assigns) do
    data = Map.to_list(assigns.data) |> Enum.sort_by(fn {_, v} -> -v end)
    max_count = data |> Enum.map(fn {_, v} -> v end) |> Enum.max(fn -> 1 end)
    assigns = assign(assigns, data: data, max_count: max_count)

    ~H"""
    <div class="space-y-3">
      <%= if Enum.empty?(@data) do %>
        <div class="py-8 text-center">
          <p class="text-base-content/40 text-sm">No data available</p>
        </div>
      <% else %>
        <%= for {label, count} <- @data do %>
          <div class="group">
            <div class="flex items-center justify-between mb-1">
              <span class="text-sm font-medium text-base-content/80">{format_label(label)}</span>
              <span class="text-sm font-mono text-base-content/60">{format_number(count)}</span>
            </div>
            <div class="h-2 bg-base-300 rounded-full overflow-hidden">
              <div
                class={"h-full rounded-full transition-all duration-500 bg-#{@color}"}
                style={"width: #{bar_width(count, @max_count)}%"}
              >
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp format_date(date) do
    Calendar.strftime(date, "%m/%d")
  end

  defp format_label(label) do
    label
    |> String.split("-")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp bar_width(count, max) when max > 0, do: max(count / max * 100, 2)
  defp bar_width(_, _), do: 0
end
