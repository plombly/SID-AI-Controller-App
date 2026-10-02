import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:laika_app/api/laika_api.dart';
import 'package:laika_app/models/laika_server.dart';
import 'package:laika_app/screens/home_screen.dart';
import 'package:laika_app/screens/vpn_screen.dart';
import 'package:laika_app/services/server_store.dart';
import 'package:laika_app/vpn/vpn_controller.dart';
import 'package:laika_app/vpn/vpn_profile.dart';
import 'package:laika_app/vpn/vpn_store.dart';

const _profile = 'client\ndev tun\nremote vpn.example.com 1194\n';
const _summary =
    '{"server_name":"LAIka Home","health":{"status":"ok"},"needs_you":{"ready":[],"stuck":[]},"in_progress":[],"recent":[]}';

const _server = LaikaServer(id: 'home', name: 'LAIka Home', url: 'http://10.0.0.59:8000', key: 'laika_test');

void main() {
  testWidgets('Home connects the server VPN before asking LAIka for the summary', (tester) async {
    final values = MemoryKeyValueStore();
    final store = ServerStore(values);
    await store.save(_server);
    final vpnStore = VpnStore(values);
    await vpnStore.save('home', const VpnProfile(config: _profile, username: 'dylan', password: 'pw'));
    final vpn = FakeVpnController();
    var connectedBeforeSummary = false;
    final api = LaikaApi(_server, client: MockClient((request) async {
      if (request.url.path == '/api/app/summary') connectedBeforeSummary = vpn.connectCalls.isNotEmpty;
      return http.Response(_summary, 200);
    }));

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(store: store, vpnStore: vpnStore, vpn: vpn, apiFor: (_) => api),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(vpn.connectCalls.single.profile.username, 'dylan');
    expect(connectedBeforeSummary, isTrue);
    expect(find.text('LAIka Home'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed VPN connection is shown instead of the summary', (tester) async {
    final values = MemoryKeyValueStore();
    final store = ServerStore(values);
    await store.save(_server);
    final vpnStore = VpnStore(values);
    await vpnStore.save('home', const VpnProfile(config: _profile, username: '', password: ''));
    final vpn = FakeVpnController(succeed: false, failWith: 'AUTH_FAILED');
    var requested = false;
    final api = LaikaApi(_server, client: MockClient((request) async {
      requested = true;
      return http.Response(_summary, 200);
    }));

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(store: store, vpnStore: vpnStore, vpn: vpn, apiFor: (_) => api),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(requested, isFalse);
    expect(find.textContaining("Couldn't connect the VPN for LAIka Home"), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('VPN screen saves a pasted profile and connects', (tester) async {
    final values = MemoryKeyValueStore();
    final vpnStore = VpnStore(values);
    final vpn = FakeVpnController();

    await tester.pumpWidget(MaterialApp(
      home: VpnScreen(server: _server, vpnStore: vpnStore, vpn: vpn),
    ));
    await tester.pump();
    expect(find.text('VPN for LAIka Home'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Or paste the profile'), 'hello');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text("This doesn't look like an OpenVPN client profile (.ovpn)"), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Or paste the profile'), _profile);
    await tester.enterText(find.widgetWithText(TextField, 'Username (if your VPN asks for one)'), 'dylan');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();
    final saved = await vpnStore.load('home');
    expect(saved?.config, _profile);
    expect(saved?.username, 'dylan');
    expect(saved?.password, 'secret');

    await tester.tap(find.text('Connect now'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Connected'), findsOneWidget);
    expect(vpn.connectCalls.single.name, 'LAIka Home');
    await tester.pumpWidget(const SizedBox());
  });
}
