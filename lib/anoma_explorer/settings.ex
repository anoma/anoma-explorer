defmodule AnomaExplorer.Settings do
  @moduledoc """
  Context module for managing contract settings.

  Provides functions for CRUD operations and querying settings.
  Settings are cached in ETS for fast reads.
  """
  import Ecto.Query

  alias AnomaExplorer.Repo
  alias AnomaExplorer.Settings.ContractSetting
  alias AnomaExplorer.Settings.Cache

  @pubsub AnomaExplorer.PubSub
  @topic "settings:changes"

  # ============================================
  # Public API - CRUD Operations
  # ============================================

  @doc """
  Creates a new contract setting.
  Broadcasts change to subscribers and updates cache.
  """
  @spec create_setting(map()) :: {:ok, ContractSetting.t()} | {:error, Ecto.Changeset.t()}
  def create_setting(attrs) do
    %ContractSetting{}
    |> ContractSetting.changeset(normalize_address(attrs))
    |> Repo.insert()
    |> tap_ok(&broadcast_change/1)
    |> tap_ok(&Cache.put/1)
  end

  @doc """
  Updates an existing contract setting.
  """
  @spec update_setting(ContractSetting.t(), map()) ::
          {:ok, ContractSetting.t()} | {:error, Ecto.Changeset.t()}
  def update_setting(%ContractSetting{} = setting, attrs) do
    setting
    |> ContractSetting.changeset(normalize_address(attrs))
    |> Repo.update()
    |> tap_ok(&broadcast_change/1)
    |> tap_ok(&Cache.put/1)
  end

  @doc """
  Deletes a contract setting.
  """
  @spec delete_setting(ContractSetting.t()) ::
          {:ok, ContractSetting.t()} | {:error, Ecto.Changeset.t()}
  def delete_setting(%ContractSetting{} = setting) do
    Repo.delete(setting)
    |> tap_ok(fn s -> Cache.delete(s.category, s.network) end)
    |> tap_ok(&broadcast_change/1)
  end

  @doc """
  Gets a single setting by ID.
  """
  @spec get_setting(integer()) :: ContractSetting.t() | nil
  def get_setting(id), do: Repo.get(ContractSetting, id)

  @doc """
  Gets a single setting by ID, raising if not found.
  """
  @spec get_setting!(integer()) :: ContractSetting.t()
  def get_setting!(id), do: Repo.get!(ContractSetting, id)

  # ============================================
  # Public API - Query Functions
  # ============================================

  @doc """
  Gets the contract address for a given category and network.
  Uses cache for fast lookups.
  """
  @spec get_address(String.t(), String.t()) :: String.t() | nil
  def get_address(category, network) do
    case Cache.get(category, network) do
      {:ok, address} -> address
      :not_found -> fetch_and_cache(category, network)
    end
  end

  @doc """
  Lists all settings with optional filters.

  ## Options
    * `:category` - Filter by category
    * `:network` - Filter by network
    * `:active` - Filter by active status (default: nil, shows all)
  """
  @spec list_settings(keyword()) :: [ContractSetting.t()]
  def list_settings(opts \\ []) do
    ContractSetting
    |> apply_filters(opts)
    |> order_by([s], asc: s.category, asc: s.network)
    |> Repo.all()
  end

  @doc """
  Lists all settings grouped by category.
  """
  @spec list_settings_by_category() :: %{String.t() => [ContractSetting.t()]}
  def list_settings_by_category do
    list_settings()
    |> Enum.group_by(& &1.category)
  end

  @doc """
  Gets all addresses for a given category across all networks.
  Returns a map of network => address.
  """
  @spec get_addresses_for_category(String.t()) :: %{String.t() => String.t()}
  def get_addresses_for_category(category) do
    ContractSetting
    |> where([s], s.category == ^category and s.active == true)
    |> select([s], {s.network, s.address})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns a changeset for tracking changes.
  """
  @spec change_setting(ContractSetting.t(), map()) :: Ecto.Changeset.t()
  def change_setting(%ContractSetting{} = setting, attrs \\ %{}) do
    ContractSetting.changeset(setting, attrs)
  end

  # ============================================
  # PubSub Broadcasting
  # ============================================

  @doc """
  Subscribe to setting changes.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  defp broadcast_change(setting) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:settings_changed, setting})
  end

  # ============================================
  # Private Helpers
  # ============================================

  defp normalize_address(attrs) when is_map(attrs) do
    case Map.get(attrs, :address) || Map.get(attrs, "address") do
      nil -> attrs
      addr -> Map.put(attrs, :address, String.downcase(addr))
    end
  end

  defp apply_filters(query, opts) do
    query
    |> filter_by_category(opts[:category])
    |> filter_by_network(opts[:network])
    |> filter_by_active(opts[:active])
  end

  defp filter_by_category(query, nil), do: query
  defp filter_by_category(query, cat), do: where(query, [s], s.category == ^cat)

  defp filter_by_network(query, nil), do: query
  defp filter_by_network(query, net), do: where(query, [s], s.network == ^net)

  defp filter_by_active(query, nil), do: query
  defp filter_by_active(query, active), do: where(query, [s], s.active == ^active)

  defp fetch_and_cache(category, network) do
    case Repo.one(
           from s in ContractSetting,
             where: s.category == ^category and s.network == ^network and s.active == true,
             select: s.address
         ) do
      nil ->
        nil

      address ->
        Cache.put_address(category, network, address)
        address
    end
  end

  defp tap_ok({:ok, result} = response, fun) do
    fun.(result)
    response
  end

  defp tap_ok(error, _fun), do: error
end
