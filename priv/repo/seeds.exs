# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     AnomaExplorer.Repo.insert!(%AnomaExplorer.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias AnomaExplorer.Repo
alias AnomaExplorer.Settings.ContractSetting

# Protocol Adapter addresses
protocol_adapter_addresses = [
  {"eth-sepolia", "0xc63336a48D0f60faD70ed027dFB256908bBD5e37"},
  {"eth-mainnet", "0xdd4f4F0875Da48EF6d8F32ACB890EC81F435Ff3a"},
  {"base-sepolia", "0x212f275c6dD4829cd84ABDF767b0Df4A9CB9ef60"},
  {"base-mainnet", "0x212f275c6dD4829cd84ABDF767b0Df4A9CB9ef60"},
  {"optimism-mainnet", "0x212f275c6dD4829cd84ABDF767b0Df4A9CB9ef60"},
  {"arb-mainnet", "0x212f275c6dD4829cd84ABDF767b0Df4A9CB9ef60"}
]

# AnomaPay ERC20 Forwarder addresses
erc20_forwarder_addresses = [
  {"eth-sepolia", "0xa04942494174eD85A11416E716262eC0AE0a065d"},
  {"eth-mainnet", "0x0D38C332135f9f0de4dcc4a6F9c918b72e2A1Df3"},
  {"base-sepolia", "0xA73Ce304460F17C3530b58BA95bCD3B89Bd38D69"},
  {"base-mainnet", "0xA73Ce304460F17C3530b58BA95bCD3B89Bd38D69"},
  {"optimism-mainnet", "0xA73Ce304460F17C3530b58BA95bCD3B89Bd38D69"},
  {"arb-mainnet", "0xA73Ce304460F17C3530b58BA95bCD3B89Bd38D69"}
]

# Helper to upsert settings
upsert_setting = fn category, {network, address} ->
  attrs = %{
    category: category,
    network: network,
    address: String.downcase(address),
    active: true
  }

  %ContractSetting{}
  |> ContractSetting.changeset(attrs)
  |> Repo.insert!(
    on_conflict: {:replace, [:address, :updated_at]},
    conflict_target: [:category, :network]
  )
end

IO.puts("Seeding Protocol Adapter addresses...")
Enum.each(protocol_adapter_addresses, &upsert_setting.("protocol_adapter", &1))

IO.puts("Seeding ERC20 Forwarder addresses...")
Enum.each(erc20_forwarder_addresses, &upsert_setting.("erc20_forwarder", &1))

IO.puts("Done! Settings seeded successfully.")
