import 'package:brick_offline_first_with_rest/src/offline_queue/rest_request_sqlite_cache_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

// Own file (and isolate): closing an in-memory connection must not disturb
// the shared in-memory manager used by rest_request_sqlite_cache_manager_test.
void main() {
  sqfliteFfiInit();

  group('RestRequestSqliteCacheManager reopen', () {
    test('a reopened in-memory queue is migrated again', () async {
      final manager = RestRequestSqliteCacheManager(
        inMemoryDatabasePath,
        databaseFactory: databaseFactoryFfi,
        processingInterval: Duration.zero,
      );
      await manager.migrate();

      await (await manager.getDb()).close();

      final results = await Future.wait([
        manager.unprocessedRequests(),
        manager.unprocessedRequests(),
      ]);
      expect(results, everyElement(isEmpty));
      await (await manager.getDb()).close();
    });

    test('a failed migration after reopening still returns the connection', () async {
      final manager = _FailingMigrationManager();
      await manager.migrate();

      await (await manager.getDb()).close();
      manager.failMigrate = true;

      final db = await manager.getDb();
      expect(db.isOpen, isTrue);
      expect(manager.migrateCalls, 2);
      await db.close();
    });
  });
}

class _FailingMigrationManager extends RestRequestSqliteCacheManager {
  bool failMigrate = false;
  int migrateCalls = 0;

  _FailingMigrationManager()
      : super(
          inMemoryDatabasePath,
          databaseFactory: databaseFactoryFfi,
          processingInterval: Duration.zero,
        );

  @override
  Future<void> migrate() async {
    migrateCalls++;
    if (failMigrate) throw StateError('migrate failed');
    await super.migrate();
  }
}
