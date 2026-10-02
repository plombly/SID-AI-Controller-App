import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/sid_server.dart';

abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureKeyValueStore implements KeyValueStore {
  const SecureKeyValueStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? values])
    : _values = values ?? <String, String>{};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

class ServerStore {
  ServerStore(this.store);

  static const String serversKey = 'sid.servers';
  static const String activeKey = 'sid.active';

  final KeyValueStore store;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  Future<List<SidServer>> servers() async {
    final value = await store.read(serversKey);
    if (value == null) {
      return <SidServer>[];
    }
    final decoded = jsonDecode(value) as List<dynamic>;
    return decoded
        .map((item) => SidServer.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(SidServer server) async {
    final current = await servers();
    final index = current.indexWhere((item) => item.id == server.id);
    if (index == -1) {
      current.add(server);
    } else {
      current[index] = server;
    }
    await store.write(
      serversKey,
      jsonEncode(current.map((item) => item.toJson()).toList()),
    );
    if (index == -1 && current.length == 1) {
      await setActive(server.id);
    }
    _changes.add(null);
  }

  Future<void> remove(String id) async {
    final current = await servers();
    final wasActive = await activeId() == id;
    current.removeWhere((server) => server.id == id);
    await store.write(
      serversKey,
      jsonEncode(current.map((item) => item.toJson()).toList()),
    );
    await store.delete('sid.vpn.$id');
    if (wasActive) {
      if (current.isEmpty) {
        await store.delete(activeKey);
      } else {
        await setActive(current.first.id);
      }
    }
    _changes.add(null);
  }

  Future<String?> activeId() => store.read(activeKey);

  Future<void> setActive(String id) async {
    await store.write(activeKey, id);
    _changes.add(null);
  }
}

String newServerId() {
  final random = Random.secure();
  return List<String>.generate(
    16,
    (_) => random.nextInt(16).toRadixString(16),
  ).join();
}
