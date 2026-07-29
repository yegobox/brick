import 'package:brick_sqlite/src/helpers/alter_column_helper.dart' show AlterColumnHelper;
import 'package:brick_sqlite/src/turso/turso_database.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// Stable temp table name for [AlterColumnHelper] table rebuilds.
///
/// Turso/libSQL normalizes unquoted identifiers to lowercase; using a
/// lowercase temp name keeps RENAME/DROP consistent and avoids orphaned
/// `temp_*` tables that break sync push.
String migrationTempTableName(String tableName) =>
    'temp_${tableName.toLowerCase()}';

/// Drops leftover `temp_*` tables from interrupted or case-mismatched migrations.
Future<void> cleanupOrphanedMigrationTempTables(Database db) async {
  if (db is! TursoSqfliteDatabase) {
    return;
  }

  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND lower(name) LIKE 'temp_%'",
  );

  for (final row in tables) {
    final name = row['name']! as String;
    await db.execute('DROP TABLE IF EXISTS "$name"');
  }

  await repairDanglingTempMigrationIndexes(db);
}

final _onTableRe = RegExp(r'\bON\s+[`"]?([^\s`"(]+)', caseSensitive: false);

/// Drops indexes whose SQL still references a missing `temp_*` table left by a
/// failed [AlterColumnHelper] rebuild (blocks Turso open / sync).
Future<void> repairDanglingTempMigrationIndexes(Database db) async {
  final indexes = await db.rawQuery(
    "SELECT name, sql FROM sqlite_master WHERE type='index' AND sql LIKE '%temp_%'",
  );

  for (final row in indexes) {
    final name = row['name'] as String?;
    final sql = row['sql'] as String?;
    if (name == null || sql == null) continue;

    final match = _onTableRe.firstMatch(sql);
    if (match == null) continue;
    final indexedTable = match.group(1)!;

    final exists = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
      [indexedTable],
    );
    if (exists.isNotEmpty) continue;

    await db.execute('DROP INDEX IF EXISTS "$name"');
  }
}
