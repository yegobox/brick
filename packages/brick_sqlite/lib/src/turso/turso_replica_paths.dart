import 'dart:io';

/// Turso embedded-replica sidecar files live next to the main database file.
///
/// `turso_dart` 0.1.x / `turso_sync_engine` uses `{db}-info` (metadata),
/// `{db}-changes`, `{db}-wal`, and `{db}-wal-revert`. Older libsql docs also
/// mention `client_wal_index` in the DB directory — we remove that too when reset.
abstract final class TursoReplicaPaths {
  /// Known sync sidecar suffixes appended to [localDbPath].
  static const syncSidecarSuffixes = <String>[
    '-info',
    '-changes',
    '-wal',
    '-wal-revert',
    '-shm',
  ];

  /// Legacy libsql sync metadata in the DB directory (pre-turso_dart naming).
  static String legacySyncMetadataPath(String localDbPath) {
    final separatorIndex = localDbPath.lastIndexOf(Platform.pathSeparator);
    final directory =
        separatorIndex <= 0 ? '.' : localDbPath.substring(0, separatorIndex);
    return '$directory${Platform.pathSeparator}client_wal_index';
  }

  /// All sidecar paths that can orphan when the main DB file is deleted.
  static List<String> syncSidecarPaths(String localDbPath) => [
        ...syncSidecarSuffixes.map((suffix) => '$localDbPath$suffix'),
        legacySyncMetadataPath(localDbPath),
      ];

  /// True when the main DB is missing/empty but Turso sync sidecars remain.
  static bool hasOrphanedSyncMetadata(String localDbPath) {
    final dbFile = File(localDbPath);
    final dbMissing = !dbFile.existsSync() || dbFile.lengthSync() == 0;
    if (!dbMissing) {
      return false;
    }
    return syncSidecarPaths(localDbPath).any((path) => File(path).existsSync());
  }

  /// Removes orphaned sync sidecars and SQLite WAL files.
  ///
  /// Safe when the main database file is missing — required before
  /// `bootstrapIfEmpty` can download a fresh replica from Turso Cloud.
  static void removeOrphanedSyncMetadata(String localDbPath) {
    for (final path in syncSidecarPaths(localDbPath)) {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  }

  static bool isOrphanedMetadataError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('metadata') &&
        (message.contains("doesn't exist") ||
            message.contains("doesn't exists") ||
            message.contains('does not exist'));
  }
}
