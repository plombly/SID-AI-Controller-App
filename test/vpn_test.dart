import 'package:flutter_test/flutter_test.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart' show VPNStage;
import 'package:laika_app/services/server_store.dart';
import 'package:laika_app/vpn/vpn_controller.dart';
import 'package:laika_app/vpn/vpn_profile.dart';
import 'package:laika_app/vpn/vpn_store.dart';

const profileText = 'client\ndev tun\nremote vpn.example.com 1194\n';

void main() {
  const profile = VpnProfile(
    config: profileText,
    username: 'alice',
    password: 'secret',
  );

  test('validates OpenVPN profiles', () {
    expect(validateOvpn(profileText), isNull);
    expect(
      validateOvpn('hello'),
      "This doesn't look like an OpenVPN client profile (.ovpn)",
    );
  });

  test('maps VPN stages to statuses', () {
    expect(statusForStage(VPNStage.exiting), VpnStatus.disconnected);
    expect(statusForStage(VPNStage.disconnected), VpnStatus.disconnected);
    expect(statusForStage(VPNStage.connected), VpnStatus.connected);
    expect(statusForStage(VPNStage.denied), VpnStatus.failed);
    expect(statusForStage(VPNStage.error), VpnStatus.failed);
    expect(statusForStage(VPNStage.connecting), VpnStatus.connecting);
  });

  test('round-trips VpnProfile JSON', () {
    expect(VpnProfile.fromJson(profile.toJson()).toJson(), profile.toJson());
  });

  test('round-trips VpnStore under the server key', () async {
    final memory = MemoryKeyValueStore();
    final store = VpnStore(memory);
    await store.save('server-1', profile);
    expect(await store.load('server-1'), isNotNull);
    expect(await memory.read('laika.vpn.server-1'), isNotNull);
    await store.remove('server-1');
    expect(await store.load('server-1'), isNull);
  });

  test('ensureConnected handles connected, success, and failure', () async {
    final already = FakeVpnController(initialStatus: VpnStatus.connected);
    await ensureConnected(already, profile, 'LAIka');
    expect(already.connectCalls, isEmpty);

    final fake = FakeVpnController();
    await ensureConnected(fake, profile, 'LAIka');
    expect(fake.connectCalls.single.name, 'LAIka');

    final failed = FakeVpnController(failWith: 'no route');
    await expectLater(
      ensureConnected(failed, profile, 'LAIka'),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains(
            "Couldn't connect the VPN for LAIka: no route",
          ),
        ),
      ),
    );
  });
}
