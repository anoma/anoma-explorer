# Anoma Explorer Indexer

Envio Hyperindex indexer for PA-EVM (Protocol Adapter) events.

## Setup

```bash
pnpm install
pnpm codegen
pnpm build
```

## Commands

| Command | Description |
|---------|-------------|
| `pnpm dev` | Run indexer in dev mode |
| `pnpm start` | Run indexer in production |
| `pnpm test` | Run GraphQL endpoint tests |
| `pnpm codegen` | Regenerate types from schema |

## GraphQL Endpoint

```
https://indexer.dev.hyperindex.xyz/d60d83b/v1/graphql
```

## Query Examples

### Entity Sample (Health Check)
```graphql
query {
  Transaction(limit: 10) { id txHash }
  Resource(limit: 10) { id tag }
  Action(limit: 10) { id actionTreeRoot }
}
```

### Recent Transactions
```graphql
query {
  Transaction(limit: 10, order_by: {blockNumber: desc}) {
    txHash
    blockNumber
    tags
    logicRefs
  }
}
```

### Transaction with Resources
```graphql
query {
  Transaction(limit: 1) {
    txHash
    tags
    resources {
      tag
      isConsumed
      logicRef
      quantity
    }
    actions {
      actionTreeRoot
      tagCount
    }
  }
}
```

### Filter Resources
```graphql
# Consumed resources (nullifiers)
query {
  Resource(where: {isConsumed: {_eq: true}}, limit: 5) {
    tag
    logicRef
    transaction { txHash }
  }
}

# Created resources (commitments)
query {
  Resource(where: {isConsumed: {_eq: false}}, limit: 5) {
    tag
    logicRef
    quantity
  }
}
```

### Commitment Tree Roots
```graphql
query {
  CommitmentTreeRoot(limit: 10, order_by: {blockNumber: desc}) {
    root
    blockNumber
    txHash
  }
}
```

### Debug Failed Decodes
```graphql
query {
  Resource(where: {decodingStatus: {_eq: "failed"}}) {
    tag
    rawBlob
    decodingError
  }
}
```

## Indexed Events

| Event | Entity |
|-------|--------|
| `TransactionExecuted` | Transaction, Resource |
| `ActionExecuted` | Action |
| `ResourcePayload` | Resource (blob decoding) |
| `DiscoveryPayload` | DiscoveryPayload |
| `ExternalPayload` | ExternalPayload |
| `ApplicationPayload` | ApplicationPayload |
| `CommitmentTreeRootAdded` | CommitmentTreeRoot |
| `ForwarderCallExecuted` | ForwarderCall |

## Tag Index Convention

Tags in `TransactionExecuted` alternate between consumed and created:
- **Even indices** (0, 2, 4...): consumed resources (nullifiers)
- **Odd indices** (1, 3, 5...): created resources (commitments)

## Testing

Run tests against the GraphQL endpoint:

```bash
# Using default endpoint
pnpm test

# Using custom endpoint
ENVIO_GRAPHQL_URL=https://your-endpoint/v1/graphql pnpm test
```
