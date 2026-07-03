# Turso Backend

Brick supports [Turso](https://docs.turso.tech/connect/dart) as an optional local database engine alongside the default sqflite backend. Apps choose the backend by injecting a `DatabaseFactory` into `SqliteProvider`.

## Local Turso

```dart
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_sqlite/turso.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';

Future<SqliteProvider<MyModel>> buildTursoProvider() async {
  final directory = await getApplicationSupportDirectory();
  final databasePath = join(directory.path, 'my_repository.db');

  return SqliteProvider(
    databasePath,
    databaseFactory: tursoDatabaseFactory(),
    modelDictionary: modelDictionary,
  );
}
```

## Embedded replica sync

Use `tursoSyncDatabaseFactory` when the local database should sync with Turso Cloud:

```dart
import 'package:brick_sqlite/turso.dart';

final syncConfig = TursoSyncConfig(
  localPath: databasePath,
  remoteUrl: tursoDatabaseUrl,
  authToken: tursoAuthToken,
  bootstrapIfEmpty: true,
);

final provider = SqliteProvider(
  syncConfig.localPath,
  databaseFactory: tursoSyncDatabaseFactory(syncConfig),
  modelDictionary: modelDictionary,
);
```

When using `OfflineFirstRepository`, call `initialize()` to pull remote changes before migrations and push local writes afterward. You can also call `repository.sync()` manually after writes.

**Get policies with Turso:** see [turso_get_policies.md](./turso_get_policies.md) for how `awaitRemoteWhenNoneExist` and `alwaysHydrate` pull from Turso Cloud before Supabase hydrate.

```dart
await repository.initialize(); // pull -> migrate -> push
await repository.sync(); // pull -> push
```

## Offline queue

Keep the offline HTTP/GraphQL request queue on sqflite. The queue database is device-local and high-churn; only the main model database should use Turso.

## Testing

`package:brick_sqlite/testing.dart` provides helpers to run integration tests against either backend:

```dart
import 'package:brick_sqlite/testing.dart';

void main() {
  const backend = BrickDatabaseBackend.turso;

  setUpAll(() async {
    await initDatabaseBackend(backend);
  });

  final provider = SqliteProvider(
    databasePathFor(backend),
    databaseFactory: databaseFactoryFor(backend),
    modelDictionary: dictionary,
  );
}
```

Turso integration tests live in `packages/brick_sqlite/test/turso/`.

## Known differences

- Turso/libSQL uses SQL-standard `"identifier"` quoting; Brick translates MySQL-style `` ` `` backticks automatically in the Turso executor.
- Unqualified column names in generated `WHERE` clauses are table-qualified (e.g. `` `Business`.id ``) so Turso resolves columns reliably.
- Turso normalizes unquoted table names to lowercase in metadata queries (`sqlite_master`, `PRAGMA table_info`).
- Turso treats `ALTER TABLE ... ADD col VARCHAR NULL` as `NOT NULL`. Brick adapts generated migration SQL automatically when using the Turso database factory.
- `PRAGMA legacy_alter_table` is unsupported; Brick skips it on Turso and uses the table-rebuild migration path without that pragma.
- Migration table rebuilds use lowercase `temp_<table>` names; orphaned `temp_*` tables are dropped before Turso sync push.

## Further reading

- [Turso Dart connection guide](https://docs.turso.tech/connect/dart)
- [SQLite provider overview](../sqlite.md)
