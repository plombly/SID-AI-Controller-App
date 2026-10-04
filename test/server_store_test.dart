import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/models/laika_server.dart';
import 'package:laika_app/services/server_store.dart';

void main() {
  LaikaServer server(String id, String name) =>
      LaikaServer(id: id, name: name, url: 'http://$id', key: 'laika_$id');

  test('saves, replaces, and tracks the active server', () async {
    final memory = MemoryKeyValueStore();
    final store = ServerStore(memory);
    await store.save(server('one', 'One'));
    expect(await store.activeId(), 'one');
    await store.save(server('one', 'Updated'));
    expect((await store.servers()).single.name, 'Updated');
  });

  test(
    'removing active servers selects the first and then clears active',
    () async {
      final store = ServerStore(MemoryKeyValueStore());
      await store.save(server('one', 'One'));
      await store.save(server('two', 'Two'));
      await store.remove('one');
      expect(await store.activeId(), 'two');
      await store.remove('two');
      expect(await store.activeId(), isNull);
    },
  );

  test('server json without alt_urls loads with empty altUrls', () {
    final loaded = LaikaServer.fromJson({
      'id': 'one',
      'name': 'One',
      'url': 'http://one',
      'key': 'laika_one',
    });
    expect(loaded.altUrls, isEmpty);
  });

  test('altUrls survive a store round trip', () async {
    final store = ServerStore(MemoryKeyValueStore());
    await store.save(const LaikaServer(
      id: 'one',
      name: 'One',
      url: 'http://one',
      key: 'laika_one',
      altUrls: ['http://two', 'http://three'],
    ));
    expect((await store.servers()).single.altUrls, [
      'http://two',
      'http://three',
    ]);
  });

  test('round-trips server data through laika.servers', () async {
    final memory = MemoryKeyValueStore();
    final store = ServerStore(memory);
    await store.save(server('one', 'One'));
    final raw = await memory.read('laika.servers');
    expect(jsonDecode(raw!), [server('one', 'One').toJson()]);
  });

  test('removing a server clears its VPN profile', () async {
    final memory = MemoryKeyValueStore(<String, String>{
      'laika.vpn.one': '{"config":"client","username":"","password":""}',
    });
    final store = ServerStore(memory);
    await store.save(server('one', 'One'));
    await store.remove('one');
    expect(await memory.read('laika.vpn.one'), isNull);
  });
}
