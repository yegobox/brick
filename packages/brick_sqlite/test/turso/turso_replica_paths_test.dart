import 'dart:io';

import 'package:brick_sqlite/src/turso/turso_replica_paths.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('brick_turso_replica_');
    dbPath = '${tempDir.path}${Platform.pathSeparator}test.sqlite';
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('hasOrphanedSyncMetadata detects turso_dart -info sidecar', () {
    File('$dbPath-info').writeAsStringSync('{}');
    expect(TursoReplicaPaths.hasOrphanedSyncMetadata(dbPath), isTrue);
  });

  test('removeOrphanedSyncMetadata deletes turso_dart sidecars', () {
    for (final suffix in TursoReplicaPaths.syncSidecarSuffixes) {
      File('$dbPath$suffix').writeAsStringSync('x');
    }
    File(TursoReplicaPaths.legacySyncMetadataPath(dbPath)).writeAsStringSync(
      'x',
    );

    TursoReplicaPaths.removeOrphanedSyncMetadata(dbPath);

    for (final path in TursoReplicaPaths.syncSidecarPaths(dbPath)) {
      expect(File(path).existsSync(), isFalse);
    }
  });

  test('hasOrphanedSyncMetadata is false when main db exists', () {
    File(dbPath).writeAsBytesSync(List<int>.filled(100, 0));
    File('$dbPath-info').writeAsStringSync('{}');
    expect(TursoReplicaPaths.hasOrphanedSyncMetadata(dbPath), isFalse);
  });
}
