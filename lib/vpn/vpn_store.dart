import 'dart:convert';

import '../services/server_store.dart';
import 'vpn_profile.dart';

class VpnStore {
  VpnStore(this.store);

  final KeyValueStore store;

  static String key(String serverId) => 'laika.vpn.$serverId';

  Future<VpnProfile?> load(String serverId) async {
    final value = await store.read(key(serverId));
    if (value == null) return null;
    return VpnProfile.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> save(String serverId, VpnProfile p) =>
      store.write(key(serverId), jsonEncode(p.toJson()));

  Future<void> remove(String serverId) => store.delete(key(serverId));
}
