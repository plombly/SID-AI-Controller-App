import 'dart:convert';

import '../models/sid_server.dart';

SidServer parsePairingCode(String text, {required String id}) {
  dynamic decoded;
  try {
    decoded = jsonDecode(text.trim());
  } on FormatException {
    throw FormatException('Not a SID pairing code');
  }

  if (decoded is! Map) {
    throw FormatException('Not a SID pairing code');
  }
  final json = decoded.cast<String, dynamic>();
  if (json['v'] != 1) {
    throw FormatException('Unsupported pairing code version');
  }

  final rawUrl = json['url'];
  if (rawUrl is! String ||
      (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://'))) {
    throw FormatException('Invalid server address');
  }
  final url = rawUrl.endsWith('/')
      ? rawUrl.substring(0, rawUrl.length - 1)
      : rawUrl;
  final rawKey = json['key'];
  if (rawKey is! String || !rawKey.startsWith('sidk_')) {
    throw FormatException('Invalid device key');
  }
  final rawName = json['name'];
  final name = rawName is String && rawName.trim().isNotEmpty
      ? rawName.trim()
      : 'SID';

  return SidServer(id: id, name: name, url: url, key: rawKey);
}
