import 'package:flutter_test/flutter_test.dart';
import 'package:sid_app/services/server_store.dart';
import 'package:sid_app/vpn/vpn_controller.dart';
import 'package:sid_app/vpn/vpn_profile.dart';
import 'package:sid_app/vpn/vpn_store.dart';

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

  test('round-trips VpnProfile JSON', () {
    expect(VpnProfile.fromJson(profile.toJson()).toJson(), profile.toJson());
  });

  test('round-trips VpnStore under the server key', () async {
    final memory = MemoryKeyValueStore();
    final store = VpnStore(memory);
    await store.save('server-1', profile);
    expect(await store.load('server-1'), isNotNull);
    expect(await memory.read('sid.vpn.server-1'), isNotNull);
    await store.remove('server-1');
    expect(await store.load('server-1'), isNull);
  });

  test('ensureConnected handles connected, success, and failure', () async {
    final already = FakeVpnController(initialStatus: VpnStatus.connected);
    await ensureConnected(already, profile, 'SID');
    expect(already.connectCalls, isEmpty);

    final fake = FakeVpnController();
    await ensureConnected(fake, profile, 'SID');
    expect(fake.connectCalls.single.name, 'SID');

    final failed = FakeVpnController(failWith: 'no route');
    await expectLater(
      ensureConnected(failed, profile, 'SID'),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains(
            "Couldn't connect the VPN for SID: no route",
          ),
        ),
      ),
    );
  });
}
