import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/laika_api.dart';
import '../models/laika_server.dart';
import '../vpn/vpn_controller.dart';
import '../vpn/vpn_profile.dart';
import '../vpn/vpn_store.dart';

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key, required this.server, required this.vpnStore, required this.vpn});

  final LaikaServer server;
  final VpnStore vpnStore;
  final VpnController vpn;

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> {
  final _profile = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  StreamSubscription<VpnStatus>? _subscription;
  VpnProfile? _saved;
  String? _error;
  bool _imported = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.vpn.changes.listen((_) { if (mounted) setState(() {}); });
    _load();
  }

  Future<void> _load() async {
    final saved = await widget.vpnStore.load(widget.server.id);
    if (!mounted) return;
    _saved = saved;
    _username.text = saved?.username ?? '';
    setState(() {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _profile.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  String _status() => switch (widget.vpn.status) {
    VpnStatus.connected => 'Connected',
    VpnStatus.connecting => 'Connecting…',
    VpnStatus.failed => 'Failed: ${widget.vpn.lastError ?? 'connection failed'}',
    VpnStatus.disconnected => 'Not connected',
  };

  Future<void> _import() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return;
    final file = files.first;
    final text = utf8.decode(await file.readAsBytes());
    final error = validateOvpn(text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else {
      setState(() { _profile.text = text; _imported = true; _error = null; });
    }
  }

  Future<void> _save() async {
    final config = _profile.text.trim().isEmpty && !_imported ? _saved?.config : _profile.text;
    final error = config == null ? "This doesn't look like an OpenVPN client profile (.ovpn)" : validateOvpn(config);
    if (error != null) { setState(() => _error = error); return; }
    await widget.vpnStore.save(widget.server.id, VpnProfile(config: config!, username: _username.text, password: _password.text.isEmpty ? (_saved?.password ?? '') : _password.text));
    if (!mounted) return;
    await _load();
    setState(() { _error = null; _profile.clear(); _imported = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VPN profile saved.')));
    }
  }

  Future<void> _connect() async {
    final saved = await widget.vpnStore.load(widget.server.id);
    if (saved == null) { setState(() => _error = "This doesn't look like an OpenVPN client profile (.ovpn)"); return; }
    try {
      await ensureConnected(widget.vpn, saved, widget.server.name);
    } on LaikaApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _remove() async {
    final remove = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      content: Text('Remove the VPN profile for ${widget.server.name}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
      ],
    ));
    if (remove == true) {
      await widget.vpnStore.remove(widget.server.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.vpn.status == VpnStatus.connected || widget.vpn.status == VpnStatus.connecting;
    return Scaffold(
      appBar: AppBar(title: Text('VPN for ${widget.server.name}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(_status(), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _import, child: const Text('Import .ovpn file')),
        if (_saved != null) const Padding(padding: EdgeInsets.only(top: 12), child: Text('A profile is saved')),
        TextField(controller: _profile, minLines: 5, maxLines: 10, decoration: const InputDecoration(labelText: 'Or paste the profile')),
        TextField(controller: _username, decoration: const InputDecoration(labelText: 'Username (if your VPN asks for one)')),
        TextField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: 'Password', hintText: _saved?.password.isNotEmpty == true ? 'Saved' : null)),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('Save')),
        OutlinedButton(onPressed: connected ? widget.vpn.disconnect : _connect, child: Text(connected ? 'Disconnect' : 'Connect now')),
        TextButton(onPressed: _remove, child: const Text('Remove VPN')),
      ]),
    );
  }
}
