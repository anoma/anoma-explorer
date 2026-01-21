defmodule AnomaExplorer.Settings.Cache do
  @moduledoc """
  ETS-based cache for contract settings.

  Provides fast concurrent reads for settings lookups.
  The GenServer owns the ETS table and handles cache population.
  """
  use GenServer

  alias AnomaExplorer.Settings.ContractSetting

  @table_name :contract_settings_cache

  # ============================================
  # Client API
  # ============================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets an address from cache.
  Returns {:ok, address} or :not_found.
  """
  @spec get(String.t(), String.t()) :: {:ok, String.t()} | :not_found
  def get(category, network) do
    key = cache_key(category, network)

    case :ets.lookup(@table_name, key) do
      [{^key, address}] -> {:ok, address}
      [] -> :not_found
    end
  end

  @doc """
  Puts a setting into the cache.
  """
  @spec put(ContractSetting.t()) :: :ok
  def put(%ContractSetting{category: category, network: network, address: address, active: true}) do
    put_address(category, network, address)
  end

  def put(%ContractSetting{category: category, network: network, active: false}) do
    delete(category, network)
  end

  @doc """
  Puts an address directly into the cache.
  """
  @spec put_address(String.t(), String.t(), String.t()) :: :ok
  def put_address(category, network, address) do
    key = cache_key(category, network)
    :ets.insert(@table_name, {key, address})
    :ok
  end

  @doc """
  Deletes an entry from cache.
  """
  @spec delete(String.t(), String.t()) :: :ok
  def delete(category, network) do
    key = cache_key(category, network)
    :ets.delete(@table_name, key)
    :ok
  end

  @doc """
  Reloads all settings from database into cache.
  """
  @spec reload_all() :: :ok
  def reload_all do
    GenServer.call(__MODULE__, :reload_all)
  end

  @doc """
  Clears the entire cache.
  """
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  # ============================================
  # Server Callbacks
  # ============================================

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:named_table, :public, :set, read_concurrency: true])

    # Load initial data from database
    load_all_settings()

    {:ok, %{table: table}}
  end

  @impl true
  def handle_call(:reload_all, _from, state) do
    clear()
    load_all_settings()
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================
  # Private Helpers
  # ============================================

  defp cache_key(category, network), do: {category, network}

  defp load_all_settings do
    # Import here to avoid circular dependency at compile time
    alias AnomaExplorer.Repo
    import Ecto.Query

    ContractSetting
    |> where([s], s.active == true)
    |> Repo.all()
    |> Enum.each(fn setting ->
      put_address(setting.category, setting.network, setting.address)
    end)
  end
end
