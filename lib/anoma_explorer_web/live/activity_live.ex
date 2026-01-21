defmodule AnomaExplorerWeb.ActivityLive do
  @moduledoc """
  LiveView for displaying contract activity feed with realtime updates.
  """
  use AnomaExplorerWeb, :live_view

  alias AnomaExplorer.Activity
  alias AnomaExplorer.Config

  @impl true
  def mount(params, _session, socket) do
    if connected?(socket) do
      subscribe_to_activities()
    end

    filters = parse_filters(params)

    socket =
      socket
      |> assign(:page_title, "Activity Feed")
      |> assign(:filters, filters)
      |> assign(:networks, ["all" | Config.supported_networks()])
      |> assign(:kinds, ["all", "tx", "log", "transfer"])
      |> stream(:activities, list_activities(filters), at: 0)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = parse_filters(params)

    socket =
      socket
      |> assign(:filters, filters)
      |> stream(:activities, list_activities(filters), reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter_params}, socket) do
    filters = %{
      network: normalize_filter(filter_params["network"]),
      kind: normalize_filter(filter_params["kind"])
    }

    params = build_query_params(filters)
    {:noreply, push_patch(socket, to: ~p"/activity?#{params}")}
  end

  @impl true
  def handle_event("load_more", %{"cursor" => cursor_id}, socket) do
    cursor_id = String.to_integer(cursor_id)
    filters = socket.assigns.filters

    more_activities = list_activities(filters, after_id: cursor_id)

    socket = stream(socket, :activities, more_activities, at: -1)
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/activity")}
  end

  @impl true
  def handle_info({:new_activity, activity}, socket) do
    if matches_filters?(activity, socket.assigns.filters) do
      {:noreply, stream_insert(socket, :activities, activity, at: 0)}
    else
      {:noreply, socket}
    end
  end

  # Private helpers

  defp subscribe_to_activities do
    for network <- Config.supported_networks() do
      Phoenix.PubSub.subscribe(AnomaExplorer.PubSub, "contract:#{network}:*")
    end

    Phoenix.PubSub.subscribe(AnomaExplorer.PubSub, "activities:new")
  end

  defp parse_filters(params) do
    %{
      network: normalize_filter(params["network"]),
      kind: normalize_filter(params["kind"])
    }
  end

  defp normalize_filter(nil), do: nil
  defp normalize_filter(""), do: nil
  defp normalize_filter("all"), do: nil
  defp normalize_filter(value), do: value

  defp list_activities(filters, opts \\ []) do
    opts =
      opts
      |> maybe_add_filter(:network, filters.network)
      |> maybe_add_filter(:kind, filters.kind)
      |> Keyword.put_new(:limit, 50)

    Activity.list_activities(opts)
  end

  defp maybe_add_filter(opts, _key, nil), do: opts
  defp maybe_add_filter(opts, key, value), do: Keyword.put(opts, key, value)

  defp matches_filters?(activity, filters) do
    matches_network?(activity, filters.network) and
      matches_kind?(activity, filters.kind)
  end

  defp matches_network?(_activity, nil), do: true
  defp matches_network?(activity, network), do: activity.network == network

  defp matches_kind?(_activity, nil), do: true
  defp matches_kind?(activity, kind), do: activity.kind == kind

  defp build_query_params(filters) do
    filters
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path="/activity">
      <!-- Page Header -->
      <div class="page-header">
        <div>
          <h1 class="page-title">Activity Feed</h1>
          <p class="text-sm text-base-content/60 mt-1">
            Real-time contract events across all networks
          </p>
        </div>
        <div class="flex items-center gap-2">
          <span class="inline-flex items-center gap-2 text-sm text-success">
            <span class="w-2 h-2 rounded-full bg-success animate-pulse"></span> Live
          </span>
        </div>
      </div>
      
    <!-- Filters -->
      <div class="stat-card mb-6">
        <form phx-change="filter" class="flex flex-wrap gap-4 items-end">
          <div class="flex-1 min-w-[200px]">
            <label class="block text-xs font-medium text-base-content/50 uppercase tracking-wider mb-2">
              Network
            </label>
            <select name="filter[network]" class="filter-select w-full">
              <%= for network <- @networks do %>
                <option
                  value={network}
                  selected={
                    @filters.network == network || (@filters.network == nil && network == "all")
                  }
                >
                  {format_network_name(network)}
                </option>
              <% end %>
            </select>
          </div>

          <div class="flex-1 min-w-[200px]">
            <label class="block text-xs font-medium text-base-content/50 uppercase tracking-wider mb-2">
              Event Type
            </label>
            <select name="filter[kind]" class="filter-select w-full">
              <%= for kind <- @kinds do %>
                <option
                  value={kind}
                  selected={@filters.kind == kind || (@filters.kind == nil && kind == "all")}
                >
                  {format_kind_name(kind)}
                </option>
              <% end %>
            </select>
          </div>

          <%= if @filters.network || @filters.kind do %>
            <button
              type="button"
              phx-click="clear_filters"
              class="px-4 py-2 text-sm text-base-content/70 hover:text-base-content transition-colors"
            >
              Clear filters
            </button>
          <% end %>
        </form>
      </div>
      
    <!-- Activity Table -->
      <div class="stat-card overflow-hidden">
        <div class="overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Block</th>
                <th>Network</th>
                <th>Type</th>
                <th>Transaction Hash</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody id="activities" phx-update="stream">
              <%= for {id, activity} <- @streams.activities do %>
                <tr id={id} class="group">
                  <td>
                    <span class="font-mono text-base-content">{activity.block_number}</span>
                  </td>
                  <td>
                    <span class={network_badge_class(activity.network)}>
                      {format_network_short(activity.network)}
                    </span>
                  </td>
                  <td>
                    <span class={kind_badge_class(activity.kind)}>
                      {activity.kind}
                    </span>
                  </td>
                  <td>
                    <span class="hash-display" title={activity.tx_hash}>
                      {truncate_hash(activity.tx_hash)}
                    </span>
                  </td>
                  <td class="text-sm text-base-content/50">
                    {format_time(activity.inserted_at)}
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_network_name("all"), do: "All Networks"
  defp format_network_name(network), do: network

  defp format_network_short(network) do
    network
    |> String.split("-")
    |> List.first()
    |> String.capitalize()
  end

  defp format_kind_name("all"), do: "All Types"
  defp format_kind_name(kind), do: String.capitalize(kind)

  defp network_badge_class(network) do
    base = "network-badge"

    cond do
      String.contains?(network, "eth") -> "#{base} network-badge-eth"
      String.contains?(network, "base") -> "#{base} network-badge-base"
      String.contains?(network, "polygon") -> "#{base} network-badge-polygon"
      String.contains?(network, "arb") -> "#{base} network-badge-arbitrum"
      String.contains?(network, "optimism") -> "#{base} network-badge-optimism"
      true -> base
    end
  end

  defp kind_badge_class(kind) do
    base = "kind-badge"

    case kind do
      "log" -> "#{base} kind-badge-log"
      "tx" -> "#{base} kind-badge-tx"
      "transfer" -> "#{base} kind-badge-transfer"
      _ -> base
    end
  end

  defp truncate_hash(nil), do: "-"

  defp truncate_hash(hash) when byte_size(hash) > 16 do
    String.slice(hash, 0, 10) <> "..." <> String.slice(hash, -6, 6)
  end

  defp truncate_hash(hash), do: hash

  defp format_time(nil), do: "-"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
end
