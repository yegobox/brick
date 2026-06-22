import 'package:brick_sqlite/src/turso/turso_executor.dart';
import 'package:brick_sqlite/src/turso/turso_transaction.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:synchronized/synchronized.dart';
import 'package:turso_dart/isolate.dart' as turso;
import 'package:turso_dart/turso_dart.dart' show TransactionBehavior;

/// Optional sync operations for embedded-replica Turso databases.
abstract class TursoSyncCapable {
  /// Fetch remote changes into the local replica.
  Future<bool> pull();

  /// Upload local writes to the remote database.
  Future<void> push();
}

/// Returns [pull] and [push] when [database] is a Turso sync database.
TursoSyncCapable? tursoSyncCapable(Database database) {
  if (database is TursoSyncCapable) {
    return database as TursoSyncCapable;
  }
  return null;
}

/// sqflite [Database] backed by Turso.
class TursoSqfliteDatabase extends TursoConnectionExecutor
    implements Database, TursoSyncCapable {
  TursoSqfliteDatabase({
    required this.path,
    required turso.Database tursoDatabase,
    required turso.Connection connection,
    required bool isSync,
  })  : _tursoDatabase = tursoDatabase,
        _isSync = isSync,
        super(connection);

  final turso.Database _tursoDatabase;
  final bool _isSync;
  final _lock = Lock(reentrant: true);
  var _isOpen = true;
  var _inTransaction = false;

  @override
  String path;

  @override
  Database get database => this;

  @override
  bool get isOpen => _isOpen;

  @override
  Future<bool> pull() async {
    _checkOpen();
    if (!_isSync) {
      return false;
    }
    return _tursoDatabase.pull();
  }

  @override
  Future<void> push() async {
    _checkOpen();
    if (!_isSync) {
      return;
    }
    await _tursoDatabase.push();
  }

  @override
  Future<void> close() async {
    if (!_isOpen) {
      return;
    }
    _isOpen = false;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) {
    return _lock.synchronized(() async {
      _checkOpen();
      if (_inTransaction) {
        throw StateError('Nested transactions are not supported');
      }
      _inTransaction = true;
      final tursoTxn = await connection.transaction(
        behavior: exclusive == true
            ? TransactionBehavior.exclusive
            : TransactionBehavior.deferred,
      );
      final txn = TursoSqfliteTransaction(tursoTxn, this);
      try {
        final result = await action(txn);
        await tursoTxn.commit();
        return result;
      } catch (error) {
        await tursoTxn.rollback();
        rethrow;
      } finally {
        _inTransaction = false;
      }
    });
  }

  @override
  Future<T> readTransaction<T>(Future<T> Function(Transaction txn) action) {
    return transaction(action);
  }

  @override
  @Deprecated('Dev only')
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) {
    throw UnimplementedError(
      'devInvokeMethod is not supported for Turso databases',
    );
  }

  @override
  @Deprecated('Dev only')
  Future<T> devInvokeSqlMethod<T>(
    String method,
    String sql, [
    List<Object?>? arguments,
  ]) {
    throw UnimplementedError(
      'devInvokeSqlMethod is not supported for Turso databases',
    );
  }

  void _checkOpen() {
    if (!_isOpen) {
      throw StateError('Database is closed');
    }
  }
}
