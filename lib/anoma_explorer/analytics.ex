defmodule AnomaExplorer.Analytics do
  @moduledoc """
  Analytics queries for contract activity data.

  Provides aggregated statistics and time-series data for the dashboard.
  """

  import Ecto.Query

  alias AnomaExplorer.Activity.ContractActivity
  alias AnomaExplorer.Repo

  @doc """
  Returns daily activity counts for the specified number of days.

  ## Options
    * `:days` - Number of days to include (default: 7)
    * `:network` - Filter by specific network
  """
  @spec daily_counts(keyword()) :: [%{date: Date.t(), count: integer()}]
  def daily_counts(opts \\ [])

  def daily_counts([]), do: []

  def daily_counts(opts) when is_list(opts) do
    days = Keyword.get(opts, :days, 7)
    network = Keyword.get(opts, :network)

    end_date = Date.utc_today()
    start_date = Date.add(end_date, -(days - 1))

    # Generate all dates in range
    date_range = Date.range(start_date, end_date)

    # Query actual counts
    query =
      from(a in ContractActivity,
        where: fragment("DATE(?)", a.inserted_at) >= ^start_date,
        where: fragment("DATE(?)", a.inserted_at) <= ^end_date,
        group_by: fragment("DATE(?)", a.inserted_at),
        select: {fragment("DATE(?)", a.inserted_at), count(a.id)}
      )

    query =
      if network do
        where(query, [a], a.network == ^network)
      else
        query
      end

    counts_map =
      query
      |> Repo.all()
      |> Map.new()

    # Return all dates with counts (0 for missing days)
    Enum.map(date_range, fn date ->
      %{date: date, count: Map.get(counts_map, date, 0)}
    end)
  end

  @doc """
  Returns activity counts grouped by kind.

  ## Options
    * `:days` - Number of days to include (default: 7)
    * `:network` - Filter by specific network
  """
  @spec activity_by_kind(keyword()) :: %{String.t() => integer()}
  def activity_by_kind(opts \\ [])

  def activity_by_kind([]), do: %{}

  def activity_by_kind(opts) when is_list(opts) do
    days = Keyword.get(opts, :days, 7)
    network = Keyword.get(opts, :network)

    start_date = Date.add(Date.utc_today(), -(days - 1))

    query =
      from(a in ContractActivity,
        where: fragment("DATE(?)", a.inserted_at) >= ^start_date,
        group_by: a.kind,
        select: {a.kind, count(a.id)}
      )

    query =
      if network do
        where(query, [a], a.network == ^network)
      else
        query
      end

    query
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns activity counts grouped by network.

  ## Options
    * `:days` - Number of days to include (default: 7)
  """
  @spec activity_by_network(keyword()) :: %{String.t() => integer()}
  def activity_by_network(opts \\ []) do
    days = Keyword.get(opts, :days, 7)

    start_date = Date.add(Date.utc_today(), -(days - 1))

    from(a in ContractActivity,
      where: fragment("DATE(?)", a.inserted_at) >= ^start_date,
      group_by: a.network,
      select: {a.network, count(a.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns summary statistics for the dashboard.

  ## Options
    * `:days` - Number of days to include (default: 7)
  """
  @spec summary_stats(keyword()) :: %{
          total_count: integer(),
          networks_active: integer(),
          kinds_used: integer(),
          avg_per_day: float()
        }
  def summary_stats(opts \\ []) do
    days = Keyword.get(opts, :days, 7)

    start_date = Date.add(Date.utc_today(), -(days - 1))

    base_query =
      from(a in ContractActivity,
        where: fragment("DATE(?)", a.inserted_at) >= ^start_date
      )

    total_count =
      base_query
      |> select([a], count(a.id))
      |> Repo.one()

    networks_active =
      base_query
      |> select([a], count(a.network, :distinct))
      |> Repo.one()

    kinds_used =
      base_query
      |> select([a], count(a.kind, :distinct))
      |> Repo.one()

    avg_per_day = if days > 0, do: total_count / days, else: 0.0

    %{
      total_count: total_count,
      networks_active: networks_active,
      kinds_used: kinds_used,
      avg_per_day: Float.round(avg_per_day, 2)
    }
  end
end
