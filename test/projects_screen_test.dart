import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:laika_app/api/laika_api.dart';
import 'package:laika_app/models/laika_server.dart';
import 'package:laika_app/screens/projects_screen.dart';
import 'package:laika_app/services/server_store.dart';
import 'package:laika_app/vpn/vpn_controller.dart';
import 'package:laika_app/vpn/vpn_store.dart';

const _server = LaikaServer(
  id: 'sid',
  name: 'LAIka',
  url: 'http://laika.test',
  key: 'key',
);

Future<ServerStore> _store() async {
  final store = ServerStore(MemoryKeyValueStore());
  await store.save(_server);
  return store;
}

const _summary = '''{"projects":[
  {"id":"sid","name":"LAIka AI Command Center","parent":"","counts":{"jobs_running":1,"jobs_queued":2}},
  {"id":"laika-app","name":"LAIka App","parent":"sid","counts":{"jobs_running":0,"jobs_queued":0,"jobs_awaiting_approval":1}}
]}''';

void main() {
  testWidgets('lists projects hierarchically and opens project details', (
    tester,
  ) async {
    final store = await _store();
    final api = LaikaApi(
      _server,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/api/projects/laika-app')) {
          return http.Response(
            jsonEncode({
              'id': 'laika-app',
              'name': 'LAIka App',
              'parent': 'sid',
              'parent_name': 'LAIka AI Command Center',
              'goals': [
                {
                  'id': 'g',
                  'summary': 'LAIka App: servers\nMore',
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
        home: ProjectsScreen(
          store: store,
          vpn: FakeVpnController(),
          vpnStore: VpnStore(MemoryKeyValueStore()),
          apiFor: (_) => api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LAIka AI Command Center'), findsOneWidget);
    expect(find.text('LAIka App'), findsOneWidget);
    expect(find.textContaining('1 to approve'), findsOneWidget);
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(
      (tiles[1].contentPadding! as EdgeInsets).left,
      greaterThan((tiles[0].contentPadding! as EdgeInsets).left),
    );
    await tester.tap(find.text('LAIka App'));
    await tester.pumpAndSettle();
    expect(find.text('Part of LAIka AI Command Center'), findsOneWidget);
    expect(find.text('LAIka App: servers'), findsOneWidget);
    expect(find.text('1 of 1 steps'), findsOneWidget);
    expect(find.text('Give LAIka work'), findsOneWidget);
  });

  testWidgets('shows no-server and server errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsScreen(
          store: ServerStore(MemoryKeyValueStore()),
          vpn: FakeVpnController(),
          vpnStore: VpnStore(MemoryKeyValueStore()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No server yet. Add one in Settings with the pairing code from LAIka.',
      ),
      findsOneWidget,
    );

    final store = await _store();
    final api = LaikaApi(
      _server,
      client: MockClient(
        (_) async => http.Response('{"detail":"Access denied"}', 403),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsScreen(
          store: store,
          vpn: FakeVpnController(),
          vpnStore: VpnStore(MemoryKeyValueStore()),
          apiFor: (_) => api,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('Access denied'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
