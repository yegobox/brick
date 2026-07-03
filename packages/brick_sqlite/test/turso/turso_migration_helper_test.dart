import 'package:brick_sqlite/src/turso/turso_migration_helper.dart';
import 'package:test/test.dart';

void main() {
  group('migrationTempTableName', () {
    test('uses lowercase temp prefix for mixed-case tables', () {
      expect(migrationTempTableName('ActualOutput'), 'temp_actualoutput');
      expect(migrationTempTableName('Business'), 'temp_business');
    });
  });
}
