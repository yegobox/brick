import 'package:sqflite_common/sqlite_api.dart';

/// Configuration for an embedded-replica Turso database.
class TursoSyncConfig {
  const TursoSyncConfig({
    required this.localPath,
    required this.remoteUrl,
    required this.authToken,
    this.bootstrapIfEmpty = false,
    this.longPollTimeout,
  });

  final String localPath;
  final String remoteUrl;
  final String authToken;
  final bool bootstrapIfEmpty;
  final Duration? longPollTimeout;
}

DatabaseFactory tursoDatabaseFactory({String? databasesPath}) =>
    throw UnsupportedError('Turso is not available on web');

DatabaseFactory tursoSyncDatabaseFactory(TursoSyncConfig config) =>
    throw UnsupportedError('Turso is not available on web');

/// Marker type for Turso [DatabaseFactory] (not available on web).
class TursoDatabaseFactory {}
