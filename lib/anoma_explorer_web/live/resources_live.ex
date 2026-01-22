defmodule AnomaExplorerWeb.ResourcesLive do
  @moduledoc """
  LiveView for listing resources from the Envio indexer.
  """
  use AnomaExplorerWeb, :live_view

  alias AnomaExplorerWeb.Layouts
  alias AnomaExplorer.Indexer.GraphQL
  alias AnomaExplorer.Indexer.Client

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: send(self(), :load_data)

    {:ok,
     socket
     |> assign(:page_title, "Resources")
     |> assign(:resources, [])
     |> assign(:loading, true)
     |> assign(:error, nil)
     |> assign(:page, 0)
     |> assign(:has_more, false)
     |> assign(:filter, nil)
     |> assign(:configured, Client.configured?())}
  end

  @impl true
  def handle_info(:load_data, socket) do
    socket = load_resources(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    filter =
      case status do
        "consumed" -> true
        "created" -> false
        _ -> nil
      end

    socket =
      socket
      |> assign(:filter, filter)
      |> assign(:page, 0)
      |> assign(:loading, true)
      |> load_resources()

    {:noreply, socket}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    socket =
      socket
      |> assign(:page, socket.assigns.page + 1)
      |> assign(:loading, true)
      |> load_resources()

    {:noreply, socket}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    socket =
      socket
      |> assign(:page, max(0, socket.assigns.page - 1))
      |> assign(:loading, true)
      |> load_resources()

    {:noreply, socket}
  end

  defp load_resources(socket) do
    if not Client.configured?() do
      socket
      |> assign(:configured, false)
      |> assign(:loading, false)
    else
      offset = socket.assigns.page * @page_size
      filter = socket.assigns.filter

      case GraphQL.list_resources(limit: @page_size + 1, offset: offset, is_consumed: filter) do
        {:ok, resources} ->
          has_more = length(resources) > @page_size
          display_resources = Enum.take(resources, @page_size)

          socket
          |> assign(:resources, display_resources)
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
    <Layouts.app flash={@flash} current_path="/resources">
      <div class="page-header">
        <div>
          <h1 class="page-title">Resources</h1>
          <p class="text-sm text-base-content/70 mt-1">
            All indexed Anoma resources
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
          <.filter_tabs filter={@filter} />

          <%= if @loading and @resources == [] do %>
            <.loading_skeleton />
          <% else %>
            <.resources_table resources={@resources} />
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
            Configure the Envio GraphQL endpoint to view resources.
          </p>
          <a href="/settings/indexer" class="btn btn-primary btn-sm mt-3">
            Configure Indexer
          </a>
        </div>
      </div>
    </div>
    """
  end

  defp filter_tabs(assigns) do
    ~H"""
    <div class="flex gap-2 mb-4">
      <button
        phx-click="filter"
        phx-value-status="all"
        class={["btn btn-sm", @filter == nil && "btn-primary" || "btn-ghost"]}
      >
        All
      </button>
      <button
        phx-click="filter"
        phx-value-status="consumed"
        class={["btn btn-sm", @filter == true && "btn-primary" || "btn-ghost"]}
      >
        <.icon name="hero-arrow-right-start-on-rectangle" class="w-4 h-4" />
        Consumed
      </button>
      <button
        phx-click="filter"
        phx-value-status="created"
        class={["btn btn-sm", @filter == false && "btn-primary" || "btn-ghost"]}
      >
        <.icon name="hero-plus-circle" class="w-4 h-4" />
        Created
      </button>
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

  defp resources_table(assigns) do
    ~H"""
    <%= if @resources == [] do %>
      <div class="text-center py-12 text-base-content/50">
        <.icon name="hero-inbox" class="w-12 h-12 mx-auto mb-2 opacity-50" />
        <p>No resources found</p>
      </div>
    <% else %>
      <div class="overflow-x-auto">
        <table class="data-table w-full">
          <thead>
            <tr>
              <th>Tag</th>
              <th>Status</th>
              <th>Logic Ref</th>
              <th class="hidden md:table-cell">Quantity</th>
              <th class="hidden lg:table-cell">Block</th>
              <th>Transaction</th>
            </tr>
          </thead>
          <tbody>
            <%= for resource <- @resources do %>
              <tr class="hover:bg-base-200/50 cursor-pointer" phx-click={JS.navigate("/resources/#{resource["id"]}")}>
                <td>
                  <code class="hash-display text-xs"><%= truncate_hash(resource["tag"]) %></code>
                </td>
                <td>
                  <%= if resource["isConsumed"] do %>
                    <span class="badge badge-error badge-sm">Consumed</span>
                  <% else %>
                    <span class="badge badge-success badge-sm">Created</span>
                  <% end %>
                </td>
                <td>
                  <code class="hash-display text-xs"><%= truncate_hash(resource["logicRef"]) %></code>
                </td>
                <td class="hidden md:table-cell">
                  <%= resource["quantity"] || "-" %>
                </td>
                <td class="hidden lg:table-cell font-mono text-sm">
                  <%= resource["blockNumber"] %>
                </td>
                <td>
                  <%= if resource["transaction"] do %>
                    <a
                      href={"/transactions/#{resource["transaction"]["txHash"]}"}
                      class="hash-display text-xs hover:text-primary"
                      phx-click={JS.navigate("/transactions/#{resource["transaction"]["txHash"]}")}
                    >
                      <%= truncate_hash(resource["transaction"]["txHash"]) %>
                    </a>
                  <% else %>
                    -
                  <% end %>
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
end
