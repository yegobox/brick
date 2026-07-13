import 'dart:io';

import 'package:brick_sqlite/turso.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Supported local database backends for Brick integration tests.
enum BrickDatabaseBackend {
  /// Default sqflite FFI SQLite backend.
  sqlite,

  /// Turso local database backend.
  turso,
}

/// Initializes the requested [backend] before opening databases in tests.
Future<void> initDatabaseBackend(BrickDatabaseBackend backend) async {
  switch (backend) {
    case BrickDatabaseBackend.sqlite:
      sqfliteFfiInit();
    case BrickDatabaseBackend.turso:
      return;
  }
}

/// Returns a [DatabaseFactory] for the requested [backend].
DatabaseFactory databaseFactoryFor(BrickDatabaseBackend backend) {
  switch (backend) {
    case BrickDatabaseBackend.sqlite:
      return databaseFactoryFfi;
    case BrickDatabaseBackend.turso:
      return tursoDatabaseFactory();
  }
}

/// Creates a unique database path for the requested [backend].
String databasePathFor(
  BrickDatabaseBackend backend, {
  String? name,
}) {
  final fileName = name ?? 'brick_${DateTime.now().microsecondsSinceEpoch}.db';
  switch (backend) {
    case BrickDatabaseBackend.sqlite:
      return '$inMemoryDatabasePath/$fileName';
    case BrickDatabaseBackend.turso:
      final directory = Directory(
        '${Directory.systemTemp.path}/brick_turso_${DateTime.now().microsecondsSinceEpoch}',
      )..createSync(recursive: true);
      return '${directory.path}/$fileName';
  }
}
