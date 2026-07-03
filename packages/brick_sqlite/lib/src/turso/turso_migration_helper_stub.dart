import 'package:sqflite_common/sqlite_api.dart';

String migrationTempTableName(String tableName) =>
    'temp_${tableName.toLowerCase()}';

Future<void> cleanupOrphanedMigrationTempTables(Database db) async {}
