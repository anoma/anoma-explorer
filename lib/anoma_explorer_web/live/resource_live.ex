defmodule AnomaExplorerWeb.ResourceLive do
  @moduledoc """
  LiveView for displaying a single resource's details.
  """
  use AnomaExplorerWeb, :live_view

  alias AnomaExplorerWeb.Layouts
  alias AnomaExplorer.Indexer.GraphQL

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: send(self(), {:load_data, id})

    {:ok,
     socket
     |> assign(:page_title, "Resource")
     |> assign(:resource, nil)
     |> assign(:loading, true)
     |> assign(:error, nil)
     |> assign(:show_raw_blob, false)
     |> assign(:resource_id, id)}
  end

  @impl true
  def handle_info({:load_data, id}, socket) do
    case GraphQL.get_resource(id) do
      {:ok, resource} ->
        {:noreply,
         socket
         |> assign(:resource, resource)
         |> assign(:loading, false)
         |> assign(:page_title, "Resource #{truncate_hash(resource["tag"])}")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, "Resource not found")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, "Error loading resource: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("toggle_raw_blob", _params, socket) do
    {:noreply, assign(socket, :show_raw_blob, not socket.assigns.show_raw_blob)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path="/resources">
      <div class="page-header">
        <div class="flex items-center gap-3">
          <a href="/resources" class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="w-4 h-4" />
          </a>
          <div>
            <h1 class="page-title">Resource Details</h1>
            <p class="text-sm text-base-content/70 mt-1">
              <%= if @resource, do: truncate_hash(@resource["tag"]), else: "Loading..." %>
            </p>
          </div>
        </div>
      </div>

      <%= if @error do %>
        <div class="alert alert-error mb-6">
          <.icon name="hero-exclamation-triangle" class="h-5 w-5" />
          <span><%= @error %></span>
        </div>
      <% end %>

      <%= if @loading do %>
        <.loading_skeleton />
      <% else %>
        <%= if @resource do %>
          <.resource_header resource={@resource} />
          <.decoded_fields resource={@resource} />
          <.raw_blob_section resource={@resource} show={@show_raw_blob} />
          <.transaction_section resource={@resource} />
        <% end %>
      <% end %>
    </Layouts.app>
    """
  end

  defp loading_skeleton(assigns) do
    ~H"""
    <div class="space-y-6 animate-pulse">
      <div class="stat-card">
        <div class="h-6 bg-base-300 rounded w-48 mb-4"></div>
        <div class="space-y-2">
          <div class="h-4 bg-base-300 rounded w-full"></div>
          <div class="h-4 bg-base-300 rounded w-3/4"></div>
        </div>
      </div>
    </div>
    """
  end

  defp resource_header(assigns) do
    ~H"""
    <div class="stat-card mb-6">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold">Overview</h2>
        <%= if @resource["isConsumed"] do %>
          <span class="badge badge-error">Consumed</span>
        <% else %>
          <span class="badge badge-success">Created</span>
        <% end %>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="md:col-span-2">
          <div class="text-xs text-base-content/60 uppercase tracking-wide mb-1">Tag</div>
          <div class="flex items-center gap-2">
            <code class="hash-display text-sm break-all"><%= @resource["tag"] %></code>
            <button
              type="button"
              phx-click={JS.dispatch("phx:copy", detail: %{text: @resource["tag"]})}
              class="btn btn-ghost btn-xs"
              title="Copy"
            >
              <.icon name="hero-clipboard-document" class="w-3 h-3" />
            </button>
          </div>
        </div>
        <div>
          <div class="text-xs text-base-content/60 uppercase tracking-wide mb-1">Index</div>
          <div class="font-mono"><%= @resource["index"] %></div>
        </div>
        <div>
          <div class="text-xs text-base-content/60 uppercase tracking-wide mb-1">Block Number</div>
          <div class="font-mono"><%= @resource["blockNumber"] %></div>
        </div>
        <div>
          <div class="text-xs text-base-content/60 uppercase tracking-wide mb-1">Chain ID</div>
          <div><span class="badge badge-outline"><%= @resource["chainId"] %></span></div>
        </div>
        <div>
          <div class="text-xs text-base-content/60 uppercase tracking-wide mb-1">Decoding Status</div>
          <.decoding_badge status={@resource["decodingStatus"]} error={@resource["decodingError"]} />
        </div>
      </div>
    </div>
    """
  end

  defp decoded_fields(assigns) do
    ~H"""
    <div class="stat-card mb-6">
      <h2 class="text-lg font-semibold mb-4">Decoded Fields</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <.field_row label="Logic Ref" value={@resource["logicRef"]} copyable />
        <.field_row label="Label Ref" value={@resource["labelRef"]} copyable />
        <.field_row label="Value Ref" value={@resource["valueRef"]} copyable />
        <.field_row label="Nullifier Key Commitment" value={@resource["nullifierKeyCommitment"]} copyable />
        <.field_row label="Nonce" value={@resource["nonce"]} copyable />
        <.field_row label="Rand Seed" value={@resource["randSeed"]} copyable />
        <.field_row label="Quantity" value={@resource["quantity"]} />
        <.field_row label="Ephemeral" value={format_bool(@resource["ephemeral"])} />
      </div>
    </div>
    """
  end

  defp field_row(assigns) do
    assigns = assign_new(assigns, :copyable, fn -> false end)

    ~H"""
    <div>
      <div class="text-xs text-base-content/60 uppercase tracking-wide mb-1"><%= @label %></div>
      <%= if @value do %>
        <div class="flex items-center gap-2">
          <code class="hash-display text-sm break-all"><%= truncate_value(@value) %></code>
          <%= if @copyable and is_binary(@value) do %>
            <button
              type="button"
              phx-click={JS.dispatch("phx:copy", detail: %{text: @value})}
              class="btn btn-ghost btn-xs shrink-0"
              title="Copy"
            >
              <.icon name="hero-clipboard-document" class="w-3 h-3" />
            </button>
          <% end %>
        </div>
      <% else %>
        <span class="text-base-content/40">-</span>
      <% end %>
    </div>
    """
  end

  defp raw_blob_section(assigns) do
    ~H"""
    <div class="stat-card mb-6">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold">Raw Blob</h2>
        <button phx-click="toggle_raw_blob" class="btn btn-ghost btn-sm">
          <%= if @show do %>
            <.icon name="hero-chevron-up" class="w-4 h-4" />
            Hide
          <% else %>
            <.icon name="hero-chevron-down" class="w-4 h-4" />
            Show
          <% end %>
        </button>
      </div>
      <%= if @show do %>
        <%= if @resource["rawBlob"] && @resource["rawBlob"] != "" do %>
          <div class="bg-base-200 rounded-lg p-4 overflow-x-auto">
            <code class="text-xs font-mono break-all whitespace-pre-wrap">
              <%= @resource["rawBlob"] %>
            </code>
          </div>
        <% else %>
          <div class="text-base-content/50 text-center py-4">No raw blob data</div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp transaction_section(assigns) do
    ~H"""
    <%= if @resource["transaction"] do %>
      <div class="stat-card">
        <h2 class="text-lg font-semibold mb-4">Parent Transaction</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="md:col-span-2">
            <div class="text-xs text-base-content/60 uppercase tracking-wide mb-1">Transaction Hash</div>
            <a href={"/transactions/#{@resource["transaction"]["id"]}"} class="hash-display text-sm hover:text-primary">
              <%= @resource["transaction"]["txHash"] %>
            </a>
          </div>
          <div>
            <div class="text-xs text-base-content/60 uppercase tracking-wide mb-1">Block</div>
            <div class="font-mono"><%= @resource["transaction"]["blockNumber"] %></div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp decoding_badge(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <%= case @status do %>
        <% "success" -> %>
          <span class="badge badge-success">Decoded</span>
        <% "failed" -> %>
          <span class="badge badge-error">Failed</span>
          <%= if @error do %>
            <span class="text-xs text-error" title={@error}>
              <.icon name="hero-information-circle" class="w-4 h-4" />
            </span>
          <% end %>
        <% "pending" -> %>
          <span class="badge badge-warning">Pending</span>
        <% _ -> %>
          <span class="badge badge-ghost"><%= @status || "-" %></span>
      <% end %>
    </div>
    """
  end

  defp truncate_hash(nil), do: "-"

  defp truncate_hash(hash) when byte_size(hash) > 20 do
    String.slice(hash, 0, 10) <> "..." <> String.slice(hash, -8, 8)
  end

  defp truncate_hash(hash), do: hash

  defp truncate_value(nil), do: nil
  defp truncate_value(val) when is_binary(val) and byte_size(val) > 50 do
    String.slice(val, 0, 24) <> "..." <> String.slice(val, -24, 24)
  end
  defp truncate_value(val), do: to_string(val)

  defp format_bool(nil), do: nil
  defp format_bool(true), do: "Yes"
  defp format_bool(false), do: "No"
end
