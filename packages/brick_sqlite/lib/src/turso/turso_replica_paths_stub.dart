/// Turso embedded-replica sidecar helpers (no-op on web).
abstract final class TursoReplicaPaths {
  static const syncSidecarSuffixes = <String>[
    '-info',
    '-changes',
    '-wal',
    '-wal-revert',
    '-shm',
  ];

  static String legacySyncMetadataPath(String localDbPath) => localDbPath;

  static List<String> syncSidecarPaths(String localDbPath) => const [];

  static bool hasOrphanedSyncMetadata(String localDbPath) => false;

  static void removeOrphanedSyncMetadata(String localDbPath) {}

  static bool isOrphanedMetadataError(Object error) => false;
}
