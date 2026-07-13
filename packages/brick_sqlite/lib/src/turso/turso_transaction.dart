import 'package:brick_sqlite/src/turso/turso_executor.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// sqflite [Transaction] backed by a Turso transaction.
class TursoSqfliteTransaction extends TursoTransactionExecutor
    implements Transaction {
  TursoSqfliteTransaction(
    super._transaction,
    super.backingDatabase,
  );
}
