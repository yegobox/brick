import 'dart:io';
import 'dart:typed_data';

import 'package:brick_sqlite/src/turso/turso_database.dart';
import 'package:brick_sqlite/src/turso/turso_replica_paths.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:synchronized/synchronized.dart';
import 'package:turso_dart/isolate.dart' as turso;
import 'package:turso_dart/turso_dart.dart' show LocalDbConfig, SyncDbConfig;

/// Configuration for an embedded-replica Turso database.
class TursoSyncConfig {
  /// Creates sync configuration for [tursoSyncDatabaseFactory].
  const TursoSyncConfig({
    required this.localPath,
    required this.remoteUrl,
    required this.authToken,
    this.bootstrapIfEmpty = false,
    this.longPollTimeout,
  });

  /// Local replica file path.
  final String localPath;

  /// Turso database URL.
  final String remoteUrl;

  /// Turso auth token.
  final String authToken;

  /// When `true`, bootstraps the local replica from remote when empty.
  final bool bootstrapIfEmpty;

  /// Optional long-poll timeout for sync operations.
  final Duration? longPollTimeout;
}

/// Local-only Turso [DatabaseFactory] for tests and offline apps.
DatabaseFactory tursoDatabaseFactory({String? databasesPath}) =>
    TursoDatabaseFactory.local(databasesPath: databasesPath);

/// Embedded-replica Turso [DatabaseFactory] with pull/push sync.
DatabaseFactory tursoSyncDatabaseFactory(TursoSyncConfig config) =>
    TursoDatabaseFactory.sync(config);

/// sqflite-compatible [DatabaseFactory] backed by Turso.
class TursoDatabaseFactory implements DatabaseFactory {
  TursoDatabaseFactory._({
    required this.databasesPath,
    this.syncConfig,
  });

  /// Local Turso databases without remote sync.
  factory TursoDatabaseFactory.local({String? databasesPath}) {
    return TursoDatabaseFactory._(
      databasesPath: databasesPath ?? _defaultDatabasesPath,
    );
  }

  /// Embedded-replica Turso databases with remote sync.
  factory TursoDatabaseFactory.sync(TursoSyncConfig config) {
    return TursoDatabaseFactory._(
      databasesPath: _parentDirectory(config.localPath),
      syncConfig: config,
    );
  }

  static const _defaultDatabasesPath = '.dart_tool/brick_turso_databases';

  final String databasesPath;
  final TursoSyncConfig? syncConfig;
  final _openDatabases = <String, TursoSqfliteDatabase>{};
  final _lock = Lock();

  @override
  Future<Database> openDatabase(
    String path, {
    OpenDatabaseOptions? options,
  }) async {
    return _lock.synchronized(() async {
      final resolvedPath = _resolvePath(path);
      final existing = _openDatabases[resolvedPath];
      if (existing != null) {
        if (existing.isOpen) {
          return existing;
        }
        _openDatabases.remove(resolvedPath);
      }

      final tursoDatabase = await _connectWithLockRetry(resolvedPath);
      final connection = await tursoDatabase.connect();
      final database = TursoSqfliteDatabase(
        path: resolvedPath,
        tursoDatabase: tursoDatabase,
        connection: connection,
        isSync: syncConfig != null,
      );
      _openDatabases[resolvedPath] = database;
      return database;
    });
  }

  Future<turso.Database> _connectWithLockRetry(String resolvedPath) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return syncConfig == null
            ? await turso.connect(LocalDbConfig(resolvedPath))
            : await turso.connectSync(
                SyncDbConfig(
                  resolvedPath,
                  remoteUrl: syncConfig!.remoteUrl,
                  authToken: syncConfig!.authToken,
                  bootstrapIfEmpty: syncConfig!.bootstrapIfEmpty,
                  longPollTimeout: syncConfig!.longPollTimeout,
                ),
              );
      } catch (e) {
        lastError = e;
        final message = e.toString();
        if (syncConfig != null &&
            TursoReplicaPaths.isOrphanedMetadataError(e) &&
            attempt < 2) {
          TursoReplicaPaths.removeOrphanedSyncMetadata(resolvedPath);
          continue;
        }
        final isLocked = message.contains('locked') ||
            message.contains('Locked') ||
            message.contains('SQLITE_BUSY');
        if (isLocked && attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 400 * (attempt + 1)),
          );
          continue;
        }
        if (isLocked) {
          throw StateError(
            'Cannot open Turso database at $resolvedPath: file is locked. '
            'Fully quit Flipper (not hot restart), close any sqlite3 or DB Browser '
            'session on this file, then relaunch.',
          );
        }
        rethrow;
      }
    }
    throw lastError!;
  }

  @override
  Future<String> getDatabasesPath() async => databasesPath;

  @override
  Future<void> setDatabasesPath(String path) async {
    throw UnsupportedError(
      'setDatabasesPath is not supported for TursoDatabaseFactory',
    );
  }

  @override
  Future<void> deleteDatabase(String path) async {
    await _lock.synchronized(() async {
      final resolvedPath = _resolvePath(path);
      final existing = _openDatabases.remove(resolvedPath);
      if (existing != null && existing.isOpen) {
        await existing.close();
      }
      final file = File(resolvedPath);
      if (await file.exists()) {
        await file.delete();
      }
      if (syncConfig != null) {
        TursoReplicaPaths.removeOrphanedSyncMetadata(resolvedPath);
      }
    });
  }

  @override
  Future<bool> databaseExists(String path) async {
    final resolvedPath = _resolvePath(path);
    return File(resolvedPath).exists();
  }

  @override
  Future<void> writeDatabaseBytes(String path, Uint8List bytes) async {
    final resolvedPath = _resolvePath(path);
    await File(resolvedPath).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List> readDatabaseBytes(String path) async {
    final resolvedPath = _resolvePath(path);
    return File(resolvedPath).readAsBytes();
  }

  String _resolvePath(String path) {
    if (syncConfig != null && path == syncConfig!.localPath) {
      return syncConfig!.localPath;
    }
    if (path.startsWith('/') || path.contains(':\\')) {
      return path;
    }
    return '$databasesPath/$path';
  }

  static String _parentDirectory(String filePath) {
    final separatorIndex = filePath.lastIndexOf(Platform.pathSeparator);
    if (separatorIndex <= 0) {
      return '.';
    }
    return filePath.substring(0, separatorIndex);
  }
}
