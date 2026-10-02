import 'package:flutter/material.dart';

import '../models/sid_server.dart';
import '../services/pairing.dart';
import '../services/server_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final ServerStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<SidServer> _servers = <SidServer>[];
  String? _activeId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final servers = await widget.store.servers();
    final activeId = await widget.store.activeId();
    if (!mounted) {
      return;
    }
    setState(() {
      _servers = servers;
      _activeId = activeId;
    });
  }

  Future<void> _addServer() async {
    final controller = TextEditingController();
    String? errorText;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add server'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Pairing code',
              errorText: errorText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final server = parsePairingCode(
                    controller.text,
                    id: newServerId(),
                  );
                  await widget.store.save(server);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  await _refresh();
                } on FormatException catch (error) {
                  setDialogState(() => errorText = error.message);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
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
                            subtitle: Text(server.url),
                            leading: Icon(
                              server.id == _activeId
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                            ),
                            onTap: () async {
                              await widget.store.setActive(server.id);
                              await _refresh();
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Remove',
                              onPressed: () => _removeServer(server),
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
