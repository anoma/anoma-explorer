defmodule AnomaExplorer.AnalyticsTest do
  use AnomaExplorer.DataCase, async: true

  alias AnomaExplorer.Analytics
  alias AnomaExplorer.Activity.ContractActivity
  alias AnomaExplorer.Repo

  @contract "0x742d35cc6634c0532925a3b844bc9e7595f0ab12"

  describe "daily_counts/1" do
    test "returns empty list when no activities exist" do
      assert Analytics.daily_counts([]) == []
    end

    test "aggregates activities by date" do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      # Create activities for today
      {:ok, _} = create_activity("eth-mainnet", today, "log")
      {:ok, _} = create_activity("eth-mainnet", today, "tx")

      # Create activity for yesterday
      {:ok, _} = create_activity("eth-mainnet", yesterday, "log")

      counts = Analytics.daily_counts(days: 7)

      today_count = Enum.find(counts, &(&1.date == today))
      yesterday_count = Enum.find(counts, &(&1.date == yesterday))

      assert today_count.count == 2
      assert yesterday_count.count == 1
    end

    test "filters by network" do
      today = Date.utc_today()

      {:ok, _} = create_activity("eth-mainnet", today, "log")
      {:ok, _} = create_activity("base-mainnet", today, "log")

      counts = Analytics.daily_counts(network: "eth-mainnet", days: 7)

      today_count = Enum.find(counts, &(&1.date == today))
      assert today_count.count == 1
    end

    test "returns counts for requested number of days" do
      counts = Analytics.daily_counts(days: 30)
      assert length(counts) == 30
    end
  end

  describe "activity_by_kind/1" do
    test "returns empty map when no activities exist" do
      assert Analytics.activity_by_kind([]) == %{}
    end

    test "groups activities by kind" do
      today = Date.utc_today()

      {:ok, _} = create_activity("eth-mainnet", today, "log")
      {:ok, _} = create_activity("eth-mainnet", today, "log")
      {:ok, _} = create_activity("eth-mainnet", today, "tx")
      {:ok, _} = create_activity("eth-mainnet", today, "transfer")

      result = Analytics.activity_by_kind(days: 7)

      assert result["log"] == 2
      assert result["tx"] == 1
      assert result["transfer"] == 1
    end

    test "filters by network" do
      today = Date.utc_today()

      {:ok, _} = create_activity("eth-mainnet", today, "log")
      {:ok, _} = create_activity("base-mainnet", today, "log")

      result = Analytics.activity_by_kind(network: "eth-mainnet", days: 7)

      assert result["log"] == 1
    end
  end

  describe "activity_by_network/1" do
    test "groups activities by network" do
      today = Date.utc_today()

      {:ok, _} = create_activity("eth-mainnet", today, "log")
      {:ok, _} = create_activity("eth-mainnet", today, "tx")
      {:ok, _} = create_activity("base-mainnet", today, "log")

      result = Analytics.activity_by_network(days: 7)

      assert result["eth-mainnet"] == 2
      assert result["base-mainnet"] == 1
    end
  end

  describe "summary_stats/1" do
    test "returns comprehensive stats" do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      {:ok, _} = create_activity("eth-mainnet", today, "log")
      {:ok, _} = create_activity("eth-mainnet", today, "tx")
      {:ok, _} = create_activity("base-mainnet", yesterday, "log")

      stats = Analytics.summary_stats(days: 7)

      assert stats.total_count == 3
      assert stats.networks_active == 2
      assert stats.kinds_used == 2
      assert is_number(stats.avg_per_day)
    end
  end

  # Helper to create activity with specific date
  defp create_activity(network, date, kind) do
    datetime = DateTime.new!(date, ~T[12:00:00], "Etc/UTC")

    activity = %ContractActivity{
      network: network,
      contract_address: @contract,
      kind: kind,
      tx_hash: "0x#{:crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)}",
      block_number: :rand.uniform(1_000_000),
      log_index: if(kind == "log", do: 0, else: nil),
      raw: %{},
      inserted_at: datetime,
      updated_at: datetime
    }

    {:ok, Repo.insert!(activity)}
  end
end
