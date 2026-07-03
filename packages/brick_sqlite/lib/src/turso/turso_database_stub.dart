/// Marker type for Turso-backed databases (not available on web).
class TursoSqfliteDatabase {}

/// Optional sync operations for embedded-replica Turso databases.
abstract class TursoSyncCapable {
  Future<bool> pull();
  Future<void> push();
}

/// Returns [pull] and [push] when [database] is a Turso sync database.
TursoSyncCapable? tursoSyncCapable(Object database) => null;
