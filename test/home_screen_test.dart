import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:laika_app/api/laika_api.dart';
import 'package:laika_app/models/laika_server.dart';
import 'package:laika_app/screens/home_screen.dart';
import 'package:laika_app/services/server_store.dart';
import 'package:laika_app/vpn/vpn_controller.dart';
import 'package:laika_app/vpn/vpn_store.dart';

const _summary =
    '''{"server_name":"LAIka Home","health":{"status":"ok"},"needs_you":{"ready":[{"id":"1","title":"Add a pause menu","project_id":"laika-app","status":"awaiting_review"}],"stuck":[{"id":"9f00aa11","title":"Stripe checkout","project_id":"shop","status":"needs_human","needs_human_kind":"network","network_request_step":"tests","network_request_reason":"network unavailable"}]},"in_progress":[{"id":"1","project_id":"laika-app","status":"running","summary":"LAIka App: servers","progress":{"total":3,"completed":1}}],"recent":[{"id":"2","project_id":"laika-app","status":"completed","summary":"Finished setup","progress":{"total":1,"completed":1}}]}''';

LaikaServer _server() => const LaikaServer(
  id: 'sid',
  name: 'LAIka',
  url: 'http://laika.test',
  key: 'secret',
);

Future<ServerStore> _store() async {
  final store = ServerStore(MemoryKeyValueStore());
  await store.save(_server());
  return store;
}

void main() {
  testWidgets('no server shows the setup message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          store: ServerStore(MemoryKeyValueStore()),
          vpn: FakeVpnController(),
          vpnStore: VpnStore(MemoryKeyValueStore()),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text(
        'No server yet. Add one in Settings with the pairing code from LAIka.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('renders the summary sections', (tester) async {
    final store = await _store();
    final api = LaikaApi(
      _server(),
      client: MockClient((_) async => http.Response(_summary, 200)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          store: store,
          vpn: FakeVpnController(),
          vpnStore: VpnStore(MemoryKeyValueStore()),
          apiFor: (_) => api,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('LAIka Home'), findsOneWidget);
    expect(find.text('Ready to approve on the LAIka dashboard'), findsOneWidget);
    expect(find.text('Wants internet access for its tests'), findsOneWidget);
    expect(find.text('1 of 3 steps'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('network approval sends the action and shows confirmation', (
    tester,
  ) async {
    final store = await _store();
    late http.Request request;
    var summaryCalls = 0;
    final api = LaikaApi(
      _server(),
      client: MockClient((received) async {
        if (received.url.path.endsWith('/actions')) {
          request = received;
          return http.Response('{"status":"pending"}', 202);
        }
        summaryCalls++;
        return http.Response(_summary, 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          store: store,
          vpn: FakeVpnController(),
          vpnStore: VpnStore(MemoryKeyValueStore()),
          apiFor: (_) => api,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Allow for this change'));
    await tester.pump();
    await tester.pump();
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(request.url.path, '/api/jobs/9f00aa11/actions');
    expect(body['action'], 'network_once');
    expect(body['expected_status'], 'needs_human');
    expect(body['request_id'], matches(RegExp(r'^[A-Za-z0-9]{16,40}$')));
    expect(summaryCalls, greaterThanOrEqualTo(2));
    expect(find.text('Sent. LAIka is on it.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('action conflict shows its detail in a snackbar', (tester) async {
    final store = await _store();
    final api = LaikaApi(
      _server(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/actions')) {
          return http.Response(
            '{"detail":"Job status is now \'queued\'; refresh and decide again"}',
            409,
          );
        }
        return http.Response(_summary, 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          store: store,
          vpn: FakeVpnController(),
          vpnStore: VpnStore(MemoryKeyValueStore()),
          apiFor: (_) => api,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Allow for this change'));
    await tester.pump();
    expect(
      find.text("Job status is now 'queued'; refresh and decide again"),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('summary unauthorized shows retry', (tester) async {
    final store = await _store();
    final api = LaikaApi(
      _server(),
      client: MockClient((_) async => http.Response('', 401)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          store: store,
          vpn: FakeVpnController(),
          vpnStore: VpnStore(MemoryKeyValueStore()),
          apiFor: (_) => api,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.text(
        "This phone's key was revoked or is not valid. Pair it again from LAIka → Settings → Phones & apps.",
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
