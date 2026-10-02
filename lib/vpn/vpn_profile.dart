import 'dart:convert';

class VpnProfile {
  const VpnProfile({
    required this.config,
    required this.username,
    required this.password,
  });

  final String config;
  final String username;
  final String password;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'config': config,
    'username': username,
    'password': password,
  };

  factory VpnProfile.fromJson(Map<String, dynamic> json) => VpnProfile(
    config: json['config'] as String,
    username: json['username'] as String,
    password: json['password'] as String,
  );

  String encode() => jsonEncode(toJson());
}

String? validateOvpn(String text) {
  final lines = text.split(RegExp(r'\r?\n'));
  final hasClient = lines.any((line) => line.trimLeft().startsWith('client'));
  final hasRemote = lines.any((line) => line.trimLeft().startsWith('remote '));
  return hasClient && hasRemote
      ? null
      : "This doesn't look like an OpenVPN client profile (.ovpn)";
}
