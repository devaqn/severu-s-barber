# Firebase Ledger Architecture

## Caixa data flow

Runtime source of truth for caixa totals is Firestore:

`barbearias/{barbeariaId}/caixas/{caixaId}/operacoes/{operationId}`

Each operation document stores:

- `tipo`: `entrada`, `sangria`, `reforco`, or `fechamento`
- `valor`: numeric value for the operation
- `timestamp`: UTC timestamp
- `userId`: Firebase Auth UID
- `operationId`: same value as the document ID
- `barbearia_id`: must match the path shop ID

The caixa document keeps immutable opening metadata plus a bounded index of
operation IDs:

- `valor_inicial` is created once and never mutated.
- `operation_ids` contains operation document IDs that can be read with
  `txn.get()` during Firestore transactions.
- `valor_final` is written only by the close transaction.

## Operations

### abrirCaixa

1. Resolve the current `barbeariaId` from `SessionManager`.
2. Read `barbearias/{shopId}/metadata/caixa_atual` inside a transaction.
3. If it points to an open caixa, abort.
4. Create the caixa document.
5. Mark the metadata document with the open caixa ID.

### sangria

1. Resolve caixa document ID.
2. Build or receive an `operationId`.
3. In a transaction, read the caixa, operation ID index, and each indexed
   operation with `txn.get()`.
4. If the operation already exists, do nothing.
5. Validate available cash from ledger values.
6. Create the `sangria` operation and append its ID to `operation_ids`.

### reforco

Same as `sangria`, but creates a `reforco` operation and increases available
cash. It never updates `valor_inicial`.

### fecharCaixa

1. Resolve caixa document ID.
2. Use deterministic close operation ID: `fechamento_{caixaId}`.
3. In a transaction, read the caixa and all indexed operations with `txn.get()`.
4. Calculate:

   `valorFinal = valorInicial + entradas + reforcos - sangrias`

5. Create the `fechamento` operation.
6. Update caixa status to `fechado`, set `data_fechamento`, `valor_final`, and
   clear the open caixa metadata document.

## Migration order

SQLite remains available until migration is verified. The runtime cutover order:

1. Run `tool/migrate_sqlite_to_firestore.dart`.
2. Validate migrated document counts and caixa ledger totals.
3. Convert model IDs to Firestore string IDs.
4. Move services fully to Firebase.
5. Remove SQLite runtime usage.
6. Delete `DatabaseHelper` last.
