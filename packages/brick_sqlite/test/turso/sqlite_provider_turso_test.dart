import 'package:brick_core/core.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_sqlite/src/db/column.dart';
import 'package:brick_sqlite/src/db/migration.dart';
import 'package:brick_sqlite/src/db/migration_commands/insert_column.dart';
import 'package:brick_sqlite/src/db/migration_commands/insert_table.dart';
import 'package:brick_sqlite/testing.dart';
import 'package:test/test.dart';

import '../__mocks__.dart';

class _UniqueFieldMigration extends Migration {
  const _UniqueFieldMigration()
      : super(
          version: 2,
          up: const [
            InsertColumn(
              'unique_field',
              Column.varchar,
              onTable: 'DemoModel',
              unique: true,
            ),
          ],
          down: const [],
        );
}

void main() {
  const backend = BrickDatabaseBackend.turso;
  late String databasePath;
  late SqliteProvider provider;

  setUpAll(() async {
    await initDatabaseBackend(backend);
    databasePath = databasePathFor(backend, name: 'provider_test.db');
    provider = SqliteProvider(
      databasePath,
      databaseFactory: databaseFactoryFor(backend),
      modelDictionary: dictionary,
    );
  });

  group('SqliteProvider (Turso)', () {
    setUp(() async {
      await provider.migrate([const DemoModelMigration()]);
      await provider.upsert<DemoModel>(DemoModel(name: 'ThomasDefault'));
      await provider.upsert<DemoModel>(DemoModel(name: 'GuyDefault'));
      await provider.upsert<DemoModel>(DemoModel(name: 'AliceDefault'));
    });

    tearDown(() async {
      await provider.resetDb();
    });

    test('#get', () async {
      final models = await provider.get<DemoModel>();
      expect(models, hasLength(3));
    });

    group('#upsert', () {
      test('insert', () async {
        final newModel = DemoModel(name: 'John');

        final newPrimaryKey = await provider.upsert<DemoModel>(newModel);
        expect(newPrimaryKey, 4);
      });

      test('update', () async {
        final newModel = DemoModel(name: 'Guy')..primaryKey = 2;

        final primaryKey = await provider.upsert<DemoModel>(newModel);
        expect(primaryKey, 2);
      });

      test('append associations', () async {
        final newModel = DemoModel(
          name: 'Guy',
          manyAssoc: [
            DemoModelAssoc(name: 'Thomas'),
            DemoModelAssoc(name: 'Alice'),
          ],
        );
        await provider.upsert<DemoModel>(newModel);
        final associationCount = await provider.get<DemoModelAssoc>();
        expect(associationCount, hasLength(2));
      });

      test('remove associations', () async {
        final newModel = DemoModel(
          name: 'Guy',
          manyAssoc: [
            DemoModelAssoc(name: 'Thomas'),
            DemoModelAssoc(name: 'Alice'),
          ],
        );
        final model = newModel
          ..primaryKey = await provider.upsert<DemoModel>(newModel);
        model.manyAssoc?.clear();
        await provider.upsert<DemoModel>(model);
        final withClearedAssociations = await provider.get<DemoModel>(
          query: Query.where(
            InsertTable.PRIMARY_KEY_FIELD,
            model.primaryKey,
            limit1: true,
          ),
        );
        expect(withClearedAssociations.first.manyAssoc, isEmpty);
      });
    });

    test('#delete', () async {
      final newModel = DemoModel(name: 'GuyDelete');

      final model = newModel
        ..primaryKey = await provider.upsert<DemoModel>(newModel);
      final doesExist = await provider.exists<DemoModel>(
        query: Query.where('name', newModel.name),
      );
      expect(doesExist, isTrue);
      final result = await provider.delete<DemoModel>(model);
      expect(result, 1);
      final existsAfterDelete = await provider.exists<DemoModel>(
        query: Query.where('name', newModel.name),
      );
      expect(existsAfterDelete, isFalse);
    });

    group('#migrate', () {
      late SqliteProvider cleanProvider;

      setUp(() {
        cleanProvider = SqliteProvider(
          databasePath,
          databaseFactory: databaseFactoryFor(backend),
          modelDictionary: dictionary,
        );
      });

      tearDown(() async {
        await cleanProvider.resetDb();
      });

      test('runs migrations for the first time', () async {
        await cleanProvider.migrate([const DemoModelMigration()]);

        final version = await cleanProvider.lastMigrationVersion();
        expect(version, 1);

        final tables = await cleanProvider.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        );
        final tableNames =
            tables.map((t) => (t['name']! as String).toLowerCase()).toList();
        expect(tableNames, contains('demomodelassoc'));
        expect(tableNames, contains('demomodel'));
      });

      test('skips migrations when already at latest version', () async {
        await cleanProvider.migrate([const DemoModelMigration()]);
        expect(await cleanProvider.lastMigrationVersion(), 1);

        await cleanProvider.migrate([const DemoModelMigration()]);
        expect(await cleanProvider.lastMigrationVersion(), 1);
      });

      test('enables foreign keys pragma', () async {
        const migration = DemoModelMigration();

        await cleanProvider.migrate([migration]);

        final result = await cleanProvider.rawQuery('PRAGMA foreign_keys');
        expect(result.first['foreign_keys'], 1);
      });

      test('schema rebuild without legacy_alter_table pragma', () async {
        await cleanProvider.migrate([const DemoModelMigration()]);
        await cleanProvider.migrate([
          const _UniqueFieldMigration(),
        ]);

        final columns = await cleanProvider.rawQuery(
          'PRAGMA table_info("DemoModel")',
        );
        expect(
          columns.map((c) => c['name']),
          contains('unique_field'),
        );

        final tempTables = await cleanProvider.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND lower(name) LIKE 'temp_%'",
        );
        expect(tempTables, isEmpty);
      });

      test('tracks migration versions correctly', () async {
        const migration1 = DemoModelMigration(2, [], []);
        const migration2 = DemoModelMigration(3, [], []);

        await cleanProvider.migrate([migration1]);
        expect(await cleanProvider.lastMigrationVersion(), 2);

        await cleanProvider.migrate([migration2]);
        expect(await cleanProvider.lastMigrationVersion(), 3);

        // ignore: invalid_use_of_protected_member
        final db = await cleanProvider.getDb();
        final versions =
            await db.query('MigrationVersions', orderBy: 'version');
        expect(versions, hasLength(3));
        expect(versions[0]['version'], 1);
        expect(versions[1]['version'], 2);
        expect(versions[2]['version'], 3);
      });

      test('runs down migrations correctly', () async {
        const migration1 = DemoModelMigration(2, [], []);
        const migration2 = DemoModelMigration(3, [], []);

        await cleanProvider.migrate([migration1]);
        expect(await cleanProvider.lastMigrationVersion(), 2);

        await cleanProvider.migrate([migration2]);
        expect(await cleanProvider.lastMigrationVersion(), 3);

        await cleanProvider.migrate([migration1, migration2], down: true);
        expect(await cleanProvider.lastMigrationVersion(), 1);

        // ignore: invalid_use_of_protected_member
        final db = await cleanProvider.getDb();
        final versions =
            await db.query('MigrationVersions', orderBy: 'version');
        expect(versions, hasLength(1));
        expect(versions[0]['version'], 1);
      });
    });

    group('#exists', () {
      test('specific', () async {
        final newModel = DemoModel(name: 'Guy');

        await provider.upsert<DemoModel>(newModel);
        final doesExist = await provider.exists<DemoModel>(
          query: Query.where('name', newModel.name),
        );
        expect(doesExist, isTrue);
      });

      test('general', () async {
        final newModel = DemoModel(name: 'Guy');

        await provider.upsert<DemoModel>(newModel);
        final doesExist = await provider.exists<DemoModel>();
        expect(doesExist, isTrue);
      });

      test('does not exist', () async {
        final doesExist = await provider.exists<DemoModel>(
          query: Query.where('name', 'Alice'),
        );
        expect(doesExist, isFalse);
      });

      test('filters by id column with table qualification', () async {
        final db = await provider.getDb();
        await db.execute('ALTER TABLE DemoModel ADD COLUMN id INTEGER');
        await db.update(
          'DemoModel',
          {'id': 42},
          where: '_brick_id = ?',
          whereArgs: [1],
        );

        final doesExist = await provider.exists<DemoModel>(
          query: Query.where('id', 42),
        );
        expect(doesExist, isTrue);
      });

      test('with an offset', () async {
        await provider.upsert<DemoModel>(DemoModel(name: 'Guy'));
        final existingModels = await provider.get<DemoModel>();
        final query = Query(limit: 1, offset: existingModels.length);

        final doesExistWithoutModel =
            await provider.exists<DemoModel>(query: query);
        expect(doesExistWithoutModel, isFalse);

        await provider.upsert<DemoModel>(DemoModel(name: 'Guy'));
        final doesExistWithModel =
            await provider.exists<DemoModel>(query: query);
        expect(doesExistWithModel, isTrue);
      });
    });

    test('with an association and an offset', () async {
      await provider.upsert<DemoModel>(
        DemoModel(name: 'Guy', manyAssoc: [DemoModelAssoc(name: 'Thomas')]),
      );
      final query = Query(
        where: [
          const Where('manyAssoc')
              .isExactly(const Where('name').isExactly('Thomas')),
        ],
        limit: 1,
        offset: 1,
      );

      final doesExistWithoutModel =
          await provider.exists<DemoModel>(query: query);
      expect(doesExistWithoutModel, isFalse);

      await provider.upsert<DemoModel>(
        DemoModel(name: 'Guy', manyAssoc: [DemoModelAssoc(name: 'Thomas')]),
      );
      final doesExistWithModel = await provider.exists<DemoModel>(query: query);
      expect(doesExistWithModel, isTrue);
    });
  });
}
