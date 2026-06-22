import 'package:brick_sqlite/src/turso/sql_binding.dart';
import 'package:test/test.dart';

void main() {
  group('prepareSqlForTurso', () {
    test('translates backticks to double quotes', () {
      expect(
        adaptSqlForTurso('SELECT COUNT(*) FROM `Business` WHERE `Business`.id = ?'),
        'SELECT COUNT(*) FROM "Business" WHERE "Business".id = ?',
      );
    });

    test('preserves string literals', () {
      expect(
        adaptSqlForTurso("SELECT * FROM `DemoModel` WHERE full_name = 'back`tick'"),
        'SELECT * FROM "DemoModel" WHERE full_name = \'back`tick\'',
      );
    });

    test('translates positional placeholders', () {
      expect(
        prepareSqlForTurso('SELECT * FROM `Business` WHERE id = ? AND name = ?'),
        'SELECT * FROM "Business" WHERE id = ?1 AND name = ?2',
      );
    });
  });
}
