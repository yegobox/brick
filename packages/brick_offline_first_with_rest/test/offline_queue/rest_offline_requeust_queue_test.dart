import 'dart:async';

import 'package:brick_offline_first_with_rest/src/offline_queue/rest_offline_queue_client.dart';
import 'package:brick_offline_first_with_rest/src/offline_queue/rest_offline_request_queue.dart';
import 'package:brick_offline_first_with_rest/src/offline_queue/rest_request_sqlite_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

import '__helpers__.dart';

void main() {
  final offlineClient = RestOfflineQueueClient(
    stubResult(),
    RestRequestSqliteCacheManager(
      'db',
      databaseFactory: databaseFactoryFfi,
    ),
  );

  group('RestOfflineRequestQueue', () {
    test('#start', () {
      final queue = RestOfflineRequestQueue(client: offlineClient)..start();
      expect(queue.isRunning, isTrue);
      queue.stop();
    });

    test('a failed tick does not throw', () async {
      final requestManager = _FailingRequestManager();
      final queue = RestOfflineRequestQueue(
        client: RestOfflineQueueClient(stubResult(), requestManager),
      );
      final errors = <Object>[];

      await runZonedGuarded(
        () async {
          queue.start();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          queue.stop();
        },
        (error, _) => errors.add(error),
      );

      expect(errors, isEmpty);
    });

    test('#stop', () {
      final queue = RestOfflineRequestQueue(client: offlineClient)..start();
      expect(queue.isRunning, isTrue);
      queue.stop();
      expect(queue.isRunning, isFalse);
    });
  });
}

class _FailingRequestManager extends RestRequestSqliteCacheManager {
  _FailingRequestManager()
      : super(
          'db',
          databaseFactory: databaseFactoryFfi,
          processingInterval: const Duration(milliseconds: 10),
        );

  @override
  Future<http.Request?> prepareNextRequestToProcess() =>
      Future.error(StateError('database_closed'));
}
