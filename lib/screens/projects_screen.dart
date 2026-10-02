import 'dart:async';

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/laika_api.dart';
import '../models/laika_server.dart';
import '../services/server_store.dart';
import 'project_screen.dart';
import '../vpn/vpn_controller.dart';
import '../vpn/vpn_store.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.store,
    required this.vpnStore,
    required this.vpn,
    this.apiFor,
  });

  final ServerStore store;
  final VpnStore vpnStore;
  final VpnController vpn;
  final LaikaApi Function(LaikaServer server)? apiFor;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  StreamSubscription<void>? _storeSubscription;
  LaikaApi? _api;
  Summary? _summary;
  LaikaApiException? _error;
  bool _loading = true;
  bool _connectingVpn = false;

  @override
  void initState() {
    super.initState();
    _storeSubscription = widget.store.changes.listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _storeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _connectingVpn = false;
      });
    }
    final activeId = await widget.store.activeId();
    final servers = await widget.store.servers();
    if (!mounted) {
      return;
    }
    final matches = servers.where((server) => server.id == activeId);
    if (matches.isEmpty) {
      setState(() {
        _api = null;
        _summary = null;
        _loading = false;
      });
      return;
    }
    final server = matches.first;
    final api = widget.apiFor?.call(server) ?? LaikaApi(server);
    _api = api;
    try {
      final profile = await widget.vpnStore.load(server.id);
      if (profile != null) {
        if (mounted) setState(() => _connectingVpn = true);
        await ensureConnected(widget.vpn, profile, server.name);
        if (mounted) setState(() => _connectingVpn = false);
      }
      final summary = await api.summary();
      if (mounted) {
        setState(() {
          _summary = summary;
          _loading = false;
        });
      }
    } on LaikaApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _connectingVpn = false;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = const LaikaApiException('Unable to load projects.');
          _connectingVpn = false;
          _loading = false;
        });
      }
    }
  }

  List<(ProjectItem, int)> _ordered(List<ProjectItem> projects) {
    final byParent = <String, List<ProjectItem>>{};
    final ids = projects.map((project) => project.id).toSet();
    for (final project in projects) {
      final parent = ids.contains(project.parent) ? project.parent : '';
      byParent.putIfAbsent(parent, () => []).add(project);
    }
    final result = <(ProjectItem, int)>[];
    void addChildren(String parent, int depth, Set<String> path) {
      for (final project in byParent[parent] ?? const <ProjectItem>[]) {
        if (!path.add(project.id)) continue;
        result.add((project, depth));
        addChildren(project.id, depth + 1, path);
        path.remove(project.id);
      }
    }

    addChildren('', 0, <String>{});
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: _loading && _summary == null
          ? Center(
              child: _connectingVpn
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Connecting VPN…'),
                      ],
                    )
                  : const CircularProgressIndicator(),
            )
          : _error != null
          ? _failure()
          : _summary == null
          ? const Center(
              child: Text(
                'No server yet. Add one in Settings with the pairing code from LAIka.',
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  for (final entry in _ordered(_summary!.projects))
                    ListTile(
                      contentPadding: EdgeInsets.only(
                        left: 16.0 + 24.0 * entry.$2,
                        right: 16,
                      ),
                      title: Text(entry.$1.name),
                      subtitle: Text(
                        '${entry.$1.running} running · ${entry.$1.queued} queued${entry.$1.awaitingApproval > 0 ? ' · ${entry.$1.awaitingApproval} to approve' : ''}',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProjectScreen(projectId: entry.$1.id, api: _api!),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _failure() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_error?.message ?? 'Unable to load projects.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: _load, child: const Text('Try again')),
      ],
    ),
  );
}
