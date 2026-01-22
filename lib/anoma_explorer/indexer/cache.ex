defmodule AnomaExplorer.Indexer.Cache do
  @moduledoc """
  ETS-based cache for GraphQL query results.

  Provides short-term caching to reduce repeated API calls to the Envio indexer.
  Cache entries expire after a configurable TTL (default: 10 seconds for stats).
  """
  use GenServer

  @table_name :indexer_cache
  @default_stats_ttl_ms 10_000
  @cleanup_interval_ms 30_000

  # Client API

  @doc """
  Starts the cache GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets a cached value if it exists and hasn't expired.

  Returns `{:ok, value}` if found and valid, `:miss` otherwise.
  """
  @spec get(term()) :: {:ok, term()} | :miss
  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:ok, value}
        else
          # Entry expired, delete it
          :ets.delete(@table_name, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  @doc """
  Stores a value in the cache with the specified TTL in milliseconds.
  """
  @spec put(term(), term(), pos_integer()) :: :ok
  def put(key, value, ttl_ms \\ @default_stats_ttl_ms) do
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(@table_name, {key, value, expires_at})
    :ok
  end

  @doc """
  Invalidates a specific cache entry.
  """
  @spec invalidate(term()) :: :ok
  def invalidate(key) do
    :ets.delete(@table_name, key)
    :ok
  end

  @doc """
  Clears all cache entries.
  """
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  @doc """
  Gets a cached value or computes it if not cached.

  If the cache misses, calls the provided function to compute the value,
  caches the result (only if successful), and returns it.
  """
  @spec get_or_compute(term(), pos_integer(), (-> {:ok, term()} | {:error, term()})) ::
          {:ok, term()} | {:error, term()}
  def get_or_compute(key, ttl_ms \\ @default_stats_ttl_ms, compute_fn) do
    case get(key) do
      {:ok, value} ->
        {:ok, value}

      :miss ->
        case compute_fn.() do
          {:ok, value} = result ->
            put(key, value, ttl_ms)
            result

          error ->
            error
        end
    end
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table with public access for fast reads
    :ets.new(@table_name, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end

  defp cleanup_expired_entries do
    now = System.monotonic_time(:millisecond)

    # Delete all expired entries
    :ets.select_delete(@table_name, [
      {{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}
    ])
  end
end
