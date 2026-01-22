defmodule AnomaExplorer.Repo.Migrations.RemoveAnomapayErc20Forwarder do
  use Ecto.Migration

  @moduledoc """
  Removes the AnomaPay ERC20 Forwarder protocol and its contract addresses.
  This contract is no longer being tracked by the explorer.
  """

  def up do
    # First delete the contract addresses associated with this protocol
    execute """
    DELETE FROM contract_addresses
    WHERE protocol_id IN (
      SELECT id FROM protocols WHERE name = 'AnomaPay ERC20 Forwarder'
    )
    """

    # Then delete the protocol itself
    execute """
    DELETE FROM protocols WHERE name = 'AnomaPay ERC20 Forwarder'
    """
  end

  def down do
    # Re-create the protocol
    execute """
    INSERT INTO protocols (name, description, github_url, active, inserted_at, updated_at)
    VALUES (
      'AnomaPay ERC20 Forwarder',
      'ERC20 token forwarder for AnomaPay',
      'https://github.com/anoma/anomapay-erc20-forwarder',
      true,
      NOW(),
      NOW()
    )
    """

    # Re-create the contract addresses
    execute """
    INSERT INTO contract_addresses (protocol_id, category, version, network, address, active, inserted_at, updated_at)
    SELECT
      p.id,
      'erc20_forwarder',
      'v1.0',
      network,
      address,
      true,
      NOW(),
      NOW()
    FROM protocols p
    CROSS JOIN (VALUES
      ('eth-sepolia', '0xa04942494174ed85a11416e716262ec0ae0a065d'),
      ('eth-mainnet', '0x0d38c332135f9f0de4dcc4a6f9c918b72e2a1df3'),
      ('base-sepolia', '0xa73ce304460f17c3530b58ba95bcd3b89bd38d69'),
      ('base-mainnet', '0xa73ce304460f17c3530b58ba95bcd3b89bd38d69'),
      ('optimism-mainnet', '0xa73ce304460f17c3530b58ba95bcd3b89bd38d69'),
      ('arb-mainnet', '0xa73ce304460f17c3530b58ba95bcd3b89bd38d69')
    ) AS addrs(network, address)
    WHERE p.name = 'AnomaPay ERC20 Forwarder'
    """
  end
end
