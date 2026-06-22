import 'package:brick_sqlite/src/turso/turso_executor.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:turso_dart/isolate.dart' as turso;

/// sqflite [Transaction] backed by a Turso transaction.
class TursoSqfliteTransaction extends TursoTransactionExecutor
    implements Transaction {
  TursoSqfliteTransaction(
    turso.Transaction transaction,
    Database backingDatabase,
  ) : super(transaction, backingDatabase);
}
