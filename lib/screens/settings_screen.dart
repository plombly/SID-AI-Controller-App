import 'package:flutter/material.dart';

import '../models/sid_server.dart';
import '../services/pairing.dart';
import '../services/server_store.dart';
import 'scan_screen.dart';
import '../vpn/vpn_controller.dart';
import '../vpn/vpn_store.dart';
import 'vpn_screen.dart';

class SettingsScreen extends StatefulWidget {
  SettingsScreen({super.key, required this.store, VpnStore? vpnStore, VpnController? vpn})
      : vpnStore = vpnStore ?? VpnStore(MemoryKeyValueStore()),
        vpn = vpn ?? FakeVpnController();

  final ServerStore store;
  final VpnStore vpnStore;
  final VpnController vpn;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<SidServer> _servers = <SidServer>[];
  final Map<String, bool> _hasVpn = <String, bool>{};
  String? _activeId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final servers = await widget.store.servers();
    final activeId = await widget.store.activeId();
    for (final server in servers) {
      _hasVpn[server.id] = await widget.vpnStore.load(server.id) != null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _servers = servers;
      _activeId = activeId;
    });
  }

  Future<void> _addServer() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AddServerDialog(store: widget.store, onSaved: _refresh),
    );
  }

  Future<void> _removeServer(SidServer server) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('Remove ${server.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true) {
      await widget.store.remove(server.id);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Servers'),
          ),
          Expanded(
            child: _servers.isEmpty
                ? const Center(
                    child: Text(
                      'No servers yet. Add one with the pairing code from '
                      'SID → Settings → Phones & apps.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView(
                    children: _servers
                        .map(
                          (server) => ListTile(
                            title: Text(server.name),
                            subtitle: Text('${server.url}${_hasVpn[server.id] == true ? ' · VPN' : ''}'),
                            leading: Icon(
                              server.id == _activeId
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                            ),
                            onTap: () async {
                              await widget.vpn.disconnect();
                              await widget.store.setActive(server.id);
                              await _refresh();
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.vpn_key_outlined),
                                  tooltip: 'VPN',
                                  onPressed: () async {
                                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VpnScreen(server: server, vpnStore: widget.vpnStore, vpn: widget.vpn)));
                                    await _refresh();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Remove',
                                  onPressed: () => _removeServer(server),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _addServer,
              child: const Text('Add server'),
            ),
          ),
        ],
      ),
    );
  }
}

class AddServerDialog extends StatefulWidget {
  const AddServerDialog({
    super.key,
    required this.store,
    required this.onSaved,
  });

  final ServerStore store;
  final Future<void> Function() onSaved;

  @override
  AddServerDialogState createState() => AddServerDialogState();
}

class AddServerDialogState extends State<AddServerDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> useScannedCode(String code) async {
    _controller.text = code;
    await _addCode();
  }

  Future<void> _addCode() async {
    try {
      final server = parsePairingCode(_controller.text, id: newServerId());
      await widget.store.save(server);
      if (mounted) {
        Navigator.pop(context);
      }
      await widget.onSaved();
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _errorText = error.message);
      }
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (mounted && code != null) {
      await useScannedCode(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add server'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR code'),
          ),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Pairing code',
              errorText: _errorText,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _addCode, child: const Text('Add')),
      ],
    );
  }
}
