defmodule AnomaExplorer.Indexer.GraphQL do
  @moduledoc """
  GraphQL client for querying the Envio Hyperindex endpoint.

  Provides functions for fetching transactions, resources, actions,
  and aggregate statistics from the indexed blockchain data.
  """

  alias AnomaExplorer.Settings

  @type transaction :: %{
          id: String.t(),
          txHash: String.t(),
          blockNumber: integer(),
          timestamp: integer(),
          chainId: integer(),
          tags: [String.t()],
          logicRefs: [String.t()]
        }

  @type resource :: %{
          id: String.t(),
          tag: String.t(),
          isConsumed: boolean(),
          blockNumber: integer(),
          chainId: integer(),
          logicRef: String.t() | nil,
          quantity: integer() | nil,
          decodingStatus: String.t(),
          transaction: %{txHash: String.t()} | nil
        }

  @type action :: %{
          id: String.t(),
          actionTreeRoot: String.t(),
          tagCount: integer(),
          blockNumber: integer(),
          timestamp: integer()
        }

  @type stats :: %{
          transactions: integer(),
          resources: integer(),
          consumed: integer(),
          created: integer(),
          actions: integer(),
          commitment_roots: integer()
        }

  @doc """
  Gets aggregate statistics for the dashboard.
  """
  @spec get_stats() :: {:ok, stats()} | {:error, term()}
  def get_stats do
    query = """
    query {
      transactions: Transaction(limit: 1000) { id }
      resources: Resource(limit: 1000) { id isConsumed }
      actions: Action(limit: 1000) { id }
      roots: CommitmentTreeRoot(limit: 1000) { id }
    }
    """

    case execute(query) do
      {:ok, data} ->
        resources = data["resources"] || []
        consumed = Enum.count(resources, & &1["isConsumed"])

        {:ok,
         %{
           transactions: length(data["transactions"] || []),
           resources: length(resources),
           consumed: consumed,
           created: length(resources) - consumed,
           actions: length(data["actions"] || []),
           commitment_roots: length(data["roots"] || [])
         }}

      error ->
        error
    end
  end

  @doc """
  Lists transactions with pagination.

  ## Options
    * `:limit` - Number of transactions to return (default: 20)
    * `:offset` - Number of transactions to skip (default: 0)
  """
  @spec list_transactions(keyword()) :: {:ok, [transaction()]} | {:error, term()}
  def list_transactions(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    query = """
    query {
      Transaction(limit: #{limit}, offset: #{offset}, order_by: {blockNumber: desc}) {
        id
        txHash
        blockNumber
        timestamp
        chainId
        tags
        logicRefs
      }
    }
    """

    case execute(query) do
      {:ok, %{"Transaction" => transactions}} ->
        {:ok, transactions}

      {:ok, _} ->
        {:ok, []}

      error ->
        error
    end
  end

  @doc """
  Gets a single transaction by ID with related data.
  """
  @spec get_transaction(String.t()) :: {:ok, map()} | {:error, term()}
  def get_transaction(id) do
    query = """
    query {
      Transaction(where: {id: {_eq: "#{id}"}}) {
        id
        txHash
        blockNumber
        timestamp
        chainId
        contractAddress
        tags
        logicRefs
        resources {
          id
          tag
          isConsumed
          logicRef
          quantity
          decodingStatus
        }
        actions {
          id
          actionTreeRoot
          tagCount
        }
      }
    }
    """

    case execute(query) do
      {:ok, %{"Transaction" => [transaction | _]}} ->
        {:ok, transaction}

      {:ok, %{"Transaction" => []}} ->
        {:error, :not_found}

      {:ok, _} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  @doc """
  Lists resources with pagination and filtering.

  ## Options
    * `:limit` - Number of resources to return (default: 20)
    * `:offset` - Number of resources to skip (default: 0)
    * `:is_consumed` - Filter by consumed status (nil for all)
  """
  @spec list_resources(keyword()) :: {:ok, [resource()]} | {:error, term()}
  def list_resources(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    is_consumed = Keyword.get(opts, :is_consumed)

    where_clause =
      case is_consumed do
        nil -> ""
        true -> ", where: {isConsumed: {_eq: true}}"
        false -> ", where: {isConsumed: {_eq: false}}"
      end

    query = """
    query {
      Resource(limit: #{limit}, offset: #{offset}, order_by: {blockNumber: desc}#{where_clause}) {
        id
        tag
        isConsumed
        blockNumber
        chainId
        logicRef
        quantity
        decodingStatus
        transaction {
          txHash
        }
      }
    }
    """

    case execute(query) do
      {:ok, %{"Resource" => resources}} ->
        {:ok, resources}

      {:ok, _} ->
        {:ok, []}

      error ->
        error
    end
  end

  @doc """
  Gets a single resource by ID with full details.
  """
  @spec get_resource(String.t()) :: {:ok, map()} | {:error, term()}
  def get_resource(id) do
    query = """
    query {
      Resource(where: {id: {_eq: "#{id}"}}) {
        id
        tag
        index
        isConsumed
        blockNumber
        chainId
        logicRef
        labelRef
        valueRef
        nullifierKeyCommitment
        nonce
        randSeed
        quantity
        ephemeral
        rawBlob
        decodingStatus
        decodingError
        transaction {
          id
          txHash
          blockNumber
        }
      }
    }
    """

    case execute(query) do
      {:ok, %{"Resource" => [resource | _]}} ->
        {:ok, resource}

      {:ok, %{"Resource" => []}} ->
        {:error, :not_found}

      {:ok, _} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  @doc """
  Lists actions with pagination.

  ## Options
    * `:limit` - Number of actions to return (default: 20)
    * `:offset` - Number of actions to skip (default: 0)
  """
  @spec list_actions(keyword()) :: {:ok, [action()]} | {:error, term()}
  def list_actions(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    query = """
    query {
      Action(limit: #{limit}, offset: #{offset}, order_by: {blockNumber: desc}) {
        id
        actionTreeRoot
        tagCount
        blockNumber
        timestamp
        transaction {
          txHash
        }
      }
    }
    """

    case execute(query) do
      {:ok, %{"Action" => actions}} ->
        {:ok, actions}

      {:ok, _} ->
        {:ok, []}

      error ->
        error
    end
  end

  # ============================================
  # Private Helpers
  # ============================================

  defp execute(query) do
    case get_url() do
      nil ->
        {:error, :not_configured}

      "" ->
        {:error, :not_configured}

      url ->
        do_request(url, query)
    end
  end

  defp get_url do
    Settings.get_envio_url()
  end

  defp do_request(url, query) do
    body = Jason.encode!(%{query: query})

    request =
      Finch.build(:post, url, [{"content-type", "application/json"}], body)

    case Finch.request(request, AnomaExplorer.Finch, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"data" => data}} ->
            {:ok, data}

          {:ok, %{"errors" => errors}} ->
            {:error, {:graphql_error, errors}}

          {:error, reason} ->
            {:error, {:decode_error, reason}}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:connection_error, reason}}
    end
  end
end
