import 'package:brick_sqlite/src/turso/sql_binding.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common/src/sql_builder.dart';
import 'package:sqflite_common/src/value_utils.dart';
import 'package:synchronized/synchronized.dart';
import 'package:turso_dart/isolate.dart' as turso;
import 'package:turso_dart/turso_dart.dart' show Params;

/// Executes SQL against a Turso [turso.Connection].
abstract class TursoConnectionExecutor implements DatabaseExecutor {
  TursoConnectionExecutor(this.connection);

  final turso.Connection connection;

  @override
  Database get database;

  final _lock = Lock();

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    return _lock.synchronized(() async {
      await connection.execute(
        prepareSqlForTurso(sql),
        params: _params(arguments),
      );
    });
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    await execute(sql, arguments);
    return _lastInsertRowId();
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final builder = SqlBuilder.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
    return rawInsert(builder.sql, builder.arguments);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    final builder = SqlBuilder.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return rawQuery(builder.sql, builder.arguments);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    checkRawArgs(arguments);
    return _lock.synchronized(() async {
      final rows = await connection.query(
        prepareSqlForTurso(sql),
        params: _params(arguments),
      );
      return mapTursoRows(rows);
    });
  }

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) async {
    final rows = await rawQuery(sql, arguments);
    return _TursoQueryCursor(rows);
  }

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) {
    final builder = SqlBuilder.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return rawQueryCursor(
      builder.sql,
      builder.arguments,
      bufferSize: bufferSize,
    );
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    await execute(sql, arguments);
    return _changes();
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final builder = SqlBuilder.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
    return rawUpdate(builder.sql, builder.arguments);
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    await execute(sql, arguments);
    return _changes();
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final builder = SqlBuilder.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
    return rawDelete(builder.sql, builder.arguments);
  }

  @override
  Batch batch() => TursoBatch(this);

  Future<int> _lastInsertRowId() async {
    final rows = await connection.query('SELECT last_insert_rowid() AS id');
    return rows.first['id'] as int;
  }

  Future<int> _changes() async {
    final rows = await connection.query('SELECT changes() AS count');
    return rows.first['count'] as int;
  }

  Params? _params(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) {
      return null;
    }
    return Params.positional(arguments);
  }
}

/// Executes SQL within a Turso [turso.Transaction].
class TursoTransactionExecutor implements DatabaseExecutor {
  TursoTransactionExecutor(this._transaction, this.backingDatabase);

  final turso.Transaction _transaction;
  final Database backingDatabase;

  @override
  Database get database => backingDatabase;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    final statement = await _transaction.prepare(prepareSqlForTurso(sql));
    try {
      await statement.execute(params: _params(arguments));
    } finally {
      await statement.dispose();
    }
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    await execute(sql, arguments);
    return _lastInsertRowId();
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final builder = SqlBuilder.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
    return rawInsert(builder.sql, builder.arguments);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    final builder = SqlBuilder.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return rawQuery(builder.sql, builder.arguments);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    checkRawArgs(arguments);
    final statement = await _transaction.prepare(prepareSqlForTurso(sql));
    try {
      final rows = await statement.query(params: _params(arguments));
      return mapTursoRows(rows);
    } finally {
      await statement.dispose();
    }
  }

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) async {
    final rows = await rawQuery(sql, arguments);
    return _TursoQueryCursor(rows);
  }

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) {
    final builder = SqlBuilder.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return rawQueryCursor(
      builder.sql,
      builder.arguments,
      bufferSize: bufferSize,
    );
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    await execute(sql, arguments);
    return _changes();
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final builder = SqlBuilder.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
    return rawUpdate(builder.sql, builder.arguments);
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    await execute(sql, arguments);
    return _changes();
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final builder = SqlBuilder.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
    return rawDelete(builder.sql, builder.arguments);
  }

  @override
  Batch batch() => TursoBatch(this);

  Future<int> _lastInsertRowId() async {
    final statement =
        await _transaction.prepare('SELECT last_insert_rowid() AS id');
    try {
      final rows = await statement.query();
      return rows.first['id'] as int;
    } finally {
      await statement.dispose();
    }
  }

  Future<int> _changes() async {
    final statement = await _transaction.prepare('SELECT changes() AS count');
    try {
      final rows = await statement.query();
      return rows.first['count'] as int;
    } finally {
      await statement.dispose();
    }
  }

  Params? _params(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) {
      return null;
    }
    return Params.positional(arguments);
  }
}

class TursoBatch implements Batch {
  TursoBatch(this._executor);

  final DatabaseExecutor _executor;
  final _operations = <Future<Object?> Function()>[];

  @override
  int get length => _operations.length;

  @override
  void execute(String sql, [List<Object?>? arguments]) {
    _operations.add(() => _executor.execute(sql, arguments));
  }

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {
    _operations.add(() => _executor.rawInsert(sql, arguments));
  }

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _operations.add(
      () => _executor.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      ),
    );
  }

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) {
    _operations.add(() => _executor.rawUpdate(sql, arguments));
  }

  @override
  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _operations.add(
      () => _executor.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      ),
    );
  }

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) {
    _operations.add(() => _executor.rawDelete(sql, arguments));
  }

  @override
  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    _operations.add(
      () => _executor.delete(table, where: where, whereArgs: whereArgs),
    );
  }

  @override
  void query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    _operations.add(
      () => _executor.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      ),
    );
  }

  @override
  void rawQuery(String sql, [List<Object?>? arguments]) {
    _operations.add(() => _executor.rawQuery(sql, arguments));
  }

  @override
  Future<List<Object?>> apply({bool? noResult, bool? continueOnError}) async {
    final results = <Object?>[];
    for (final operation in _operations) {
      try {
        results.add(await operation());
      } catch (error) {
        if (continueOnError != true) {
          rethrow;
        }
        results.add(error);
      }
    }
    return results;
  }

  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) {
    return _executor.database.transaction((txn) async {
      final batch = TursoBatch(txn);
      batch._operations.addAll(_operations);
      return batch.apply(noResult: noResult, continueOnError: continueOnError);
    });
  }
}

class _TursoQueryCursor implements QueryCursor {
  _TursoQueryCursor(this._rows);

  final List<Map<String, Object?>> _rows;
  var _index = -1;
  var _closed = false;

  @override
  Map<String, Object?> get current {
    if (_index < 0 || _index >= _rows.length) {
      throw StateError('Cursor is not positioned on a row');
    }
    return _rows[_index];
  }

  @override
  Future<bool> moveNext() async {
    if (_closed) {
      return false;
    }
    _index += 1;
    if (_index >= _rows.length) {
      await close();
      return false;
    }
    return true;
  }

  @override
  Future<void> close() async {
    _closed = true;
  }
}
