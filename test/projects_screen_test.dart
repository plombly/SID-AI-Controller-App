import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sid_app/api/sid_api.dart';
import 'package:sid_app/models/sid_server.dart';
import 'package:sid_app/screens/projects_screen.dart';
import 'package:sid_app/services/server_store.dart';

const _server = SidServer(
  id: 'sid',
  name: 'SID',
  url: 'http://sid.test',
  key: 'key',
);

Future<ServerStore> _store() async {
  final store = ServerStore(MemoryKeyValueStore());
  await store.save(_server);
  return store;
}

const _summary = '''{"projects":[
  {"id":"sid","name":"SID AI Command Center","parent":"","counts":{"jobs_running":1,"jobs_queued":2}},
  {"id":"sid-app","name":"SID App","parent":"sid","counts":{"jobs_running":0,"jobs_queued":0,"jobs_awaiting_approval":1}}
]}''';

void main() {
  testWidgets('lists projects hierarchically and opens project details', (
    tester,
  ) async {
    final store = await _store();
    final api = SidApi(
      _server,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/api/projects/sid-app')) {
          return http.Response(
            jsonEncode({
              'id': 'sid-app',
              'name': 'SID App',
              'parent': 'sid',
              'parent_name': 'SID AI Command Center',
              'goals': [
                {
                  'id': 'g',
                  'summary': 'SID App: servers\nMore',
                  'status': 'completed',
                  'progress': {'total': 1, 'completed': 1},
                },
              ],
              'jobs': [],
            }),
            200,
          );
        }
        return http.Response(_summary, 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsScreen(store: store, apiFor: (_) => api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SID AI Command Center'), findsOneWidget);
    expect(find.text('SID App'), findsOneWidget);
    expect(find.textContaining('1 to approve'), findsOneWidget);
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(
      (tiles[1].contentPadding! as EdgeInsets).left,
      greaterThan((tiles[0].contentPadding! as EdgeInsets).left),
    );
    await tester.tap(find.text('SID App'));
    await tester.pumpAndSettle();
    expect(find.text('Part of SID AI Command Center'), findsOneWidget);
    expect(find.text('SID App: servers'), findsOneWidget);
    expect(find.text('1 of 1 steps'), findsOneWidget);
    expect(find.text('Give SID work'), findsOneWidget);
  });

  testWidgets('shows no-server and server errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsScreen(store: ServerStore(MemoryKeyValueStore())),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No server yet. Add one in Settings with the pairing code from SID.',
      ),
      findsOneWidget,
    );

    final store = await _store();
    final api = SidApi(
      _server,
      client: MockClient(
        (_) async => http.Response('{"detail":"Access denied"}', 403),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsScreen(store: store, apiFor: (_) => api),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('Access denied'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
