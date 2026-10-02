import 'dart:async';
import 'dart:io';

import 'package:openvpn_flutter/openvpn_flutter.dart';

import '../api/sid_api.dart';
import 'vpn_profile.dart';

enum VpnStatus { disconnected, connecting, connected, failed }

abstract class VpnController {
  VpnStatus get status;
  Stream<VpnStatus> get changes;
  String? get lastError;
  Future<void> connect(VpnProfile profile, {required String name});
  Future<void> disconnect();
}

class OpenVpnController implements VpnController {
  OpenVpnController() {
    _openvpn = OpenVPN(onVpnStageChanged: _onStageChanged);
  }

  late final OpenVPN _openvpn;
  final StreamController<VpnStatus> _changes =
      StreamController<VpnStatus>.broadcast();
  VpnStatus _status = VpnStatus.disconnected;
  String? _lastError;
  Future<void>? _initializing;
  bool _permissionRequested = false;

  @override
  VpnStatus get status => _status;
  @override
  Stream<VpnStatus> get changes => _changes.stream;
  @override
  String? get lastError => _lastError;

  Future<void> _initialize() => _initializing ??= _openvpn.initialize(
    groupIdentifier: 'group.dev.sid.sidApp',
    providerBundleIdentifier: 'dev.sid.sidApp.VPNExtension',
    localizedDescription: 'SID VPN',
  );

  void _onStageChanged(VPNStage stage, String rawStage) {
    final next = switch (stage) {
      VPNStage.connected => VpnStatus.connected,
      VPNStage.disconnected => VpnStatus.disconnected,
      VPNStage.denied || VPNStage.error || VPNStage.exiting => VpnStatus.failed,
      _ => VpnStatus.connecting,
    };
    if (next == VpnStatus.failed) _lastError = rawStage;
    if (next == VpnStatus.connected) _lastError = null;
    _status = next;
    _changes.add(next);
  }

  @override
  Future<void> connect(VpnProfile profile, {required String name}) async {
    await _initialize();
    if (Platform.isAndroid && !_permissionRequested) {
      _permissionRequested = true;
      if (!await _openvpn.requestPermissionAndroid()) {
        _lastError = 'VPN permission denied';
        _status = VpnStatus.failed;
        _changes.add(_status);
        return;
      }
    }
    _status = VpnStatus.connecting;
    _changes.add(_status);
    await _openvpn.connect(
      profile.config,
      name,
      username: profile.username.isEmpty ? null : profile.username,
      password: profile.password.isEmpty ? null : profile.password,
      certIsRequired: false,
    );
  }

  @override
  Future<void> disconnect() async {
    _openvpn.disconnect();
    _status = VpnStatus.disconnected;
    _changes.add(_status);
  }
}

class FakeVpnCall {
  const FakeVpnCall(this.name, this.profile);
  final String name;
  final VpnProfile profile;
}

class FakeVpnController implements VpnController {
  FakeVpnController({
    this.succeed = true,
    this.failWith,
    VpnStatus initialStatus = VpnStatus.disconnected,
  }) : _status = initialStatus;

  bool succeed;
  String? failWith;
  final List<FakeVpnCall> connectCalls = <FakeVpnCall>[];
  int disconnectCalls = 0;
  final StreamController<VpnStatus> _changes =
      StreamController<VpnStatus>.broadcast();
  VpnStatus _status;
  String? _lastError;

  @override
  VpnStatus get status => _status;
  @override
  Stream<VpnStatus> get changes => _changes.stream;
  @override
  String? get lastError => _lastError;

  @override
  Future<void> connect(VpnProfile profile, {required String name}) async {
    connectCalls.add(FakeVpnCall(name, profile));
    _status = VpnStatus.connecting;
    _changes.add(_status);
    if (succeed && failWith == null) {
      _status = VpnStatus.connected;
      _changes.add(_status);
    } else {
      _lastError = failWith ?? 'connection failed';
      _status = VpnStatus.failed;
      _changes.add(_status);
    }
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    _status = VpnStatus.disconnected;
    _changes.add(_status);
  }
}

Future<void> ensureConnected(
  VpnController vpn,
  VpnProfile profile,
  String name, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  if (vpn.status == VpnStatus.connected) return;
  final done = Completer<void>();
  late final StreamSubscription<VpnStatus> subscription;
  subscription = vpn.changes.listen((status) {
    if (status == VpnStatus.connected && !done.isCompleted) {
      done.complete();
    } else if (status == VpnStatus.failed && !done.isCompleted) {
      done.completeError(
        SidApiException(
          "Couldn't connect the VPN for $name: ${vpn.lastError ?? 'timed out'}",
        ),
      );
    }
  });
  try {
    await vpn.connect(profile, name: name);
    if (vpn.status == VpnStatus.connected && !done.isCompleted) done.complete();
    await done.future.timeout(timeout);
  } on TimeoutException {
    throw SidApiException(
      "Couldn't connect the VPN for $name: ${vpn.lastError ?? 'timed out'}",
    );
  } finally {
    await subscription.cancel();
  }
}
