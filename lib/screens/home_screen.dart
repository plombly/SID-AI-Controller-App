import 'dart:async';

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/sid_api.dart';
import '../models/sid_server.dart';
import '../services/server_store.dart';
import '../vpn/vpn_controller.dart';
import '../vpn/vpn_store.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({super.key, required this.store, VpnStore? vpnStore, VpnController? vpn, this.apiFor})
      : vpnStore = vpnStore ?? VpnStore(MemoryKeyValueStore()),
        vpn = vpn ?? FakeVpnController();

  final ServerStore store;
  final VpnStore vpnStore;
  final VpnController vpn;
  final SidApi Function(SidServer server)? apiFor;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SidServer? _server;
  SidApi? _api;
  Summary? _summary;
  SidApiException? _error;
  bool _loading = true;
  bool _connectingVpn = false;
  String? _actionJobId;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
    if (!mounted) return;
    final matching = servers.where((item) => item.id == activeId);
    final server = matching.isEmpty ? null : matching.first;
    if (server == null) {
      setState(() {
        _server = null;
        _api = null;
        _summary = null;
        _loading = false;
      });
      return;
    }
    final api = widget.apiFor?.call(server) ?? SidApi(server);
    setState(() {
      _server = server;
      _api = api;
    });
    try {
      final profile = await widget.vpnStore.load(server.id);
      if (profile != null) {
        if (mounted) setState(() => _connectingVpn = true);
        await ensureConnected(widget.vpn, profile, server.name);
        if (mounted) setState(() => _connectingVpn = false);
      }
      final summary = await api.summary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } on SidApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _connectingVpn = false;
        _loading = false;
      });
    }
  }

  Future<void> _performAction(JobItem job, String action) async {
    if (_actionJobId != null) return;
    setState(() => _actionJobId = job.id);
    try {
      await _api!.jobAction(job.id, action);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sent. SID is on it.')));
      await _load();
    } on SidApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _actionJobId = null);
    }
  }

  Future<void> _reject(JobItem job) async {
    final giveUp = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Give up on ${job.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Give up'),
          ),
        ],
      ),
    );
    if (giveUp == true && mounted) await _performAction(job, 'reject');
  }

  String _firstLine(String value) => value.split('\n').first;

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  Widget _jobCard(JobItem job) {
    final busy = _actionJobId == job.id;
    if (job.wantsInternet) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(job.title, style: Theme.of(context).textTheme.titleMedium),
              Text(
                'Wants internet access for its ${job.networkRequestStep ?? 'tests'}',
              ),
              Text(
                job.networkRequestReason ?? '',
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => _performAction(job, 'network_once'),
                    child: const Text('Allow for this change'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _performAction(job, 'network_always'),
                    child: const Text('Always allow in this project'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => _performAction(job, 'network_deny'),
                    child: const Text('Keep tests offline'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.title, style: Theme.of(context).textTheme.titleMedium),
            const Text('Stuck: SID gave up after several tries'),
            Row(
              children: [
                FilledButton(
                  onPressed: busy ? null : () => _performAction(job, 'extend'),
                  child: const Text('Try again'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: busy ? null : () => _reject(job),
                  child: const Text('Give up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(Summary summary) {
    final needsYou = <Widget>[
      ...summary.ready.map(
        (job) => Card(
          child: ListTile(
            title: Text(job.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.projectId),
                const Text('Ready to approve on the SID dashboard'),
              ],
            ),
          ),
        ),
      ),
      ...summary.stuck.map(_jobCard),
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _section(
          'Status',
          Text(summary.healthStatus == 'ok' ? 'All good' : 'Needs attention'),
        ),
        _section(
          'Needs you',
          needsYou.isEmpty
              ? const Text('Nothing needs you right now.')
              : Column(children: needsYou),
        ),
        _section(
          'In progress',
          summary.inProgress.isEmpty
              ? const Text('SID is idle.')
              : Column(
                  children: summary.inProgress
                      .map(
                        (goal) => ListTile(
                          title: Text(_firstLine(goal.summary), maxLines: 2),
                          subtitle: Text(
                            '${goal.completed} of ${goal.total} steps',
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        _section(
          'Recently finished',
          summary.recent.isEmpty
              ? const Text('Nothing finished yet.')
              : Column(
                  children: summary.recent
                      .take(5)
                      .map(
                        (goal) => ListTile(
                          leading: Icon(
                            goal.status == 'completed'
                                ? Icons.check_circle
                                : Icons.cancel,
                          ),
                          title: Text(_firstLine(goal.summary)),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_server == null && !_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: const Center(
          child: Text(
            'No server yet. Add one in Settings with the pairing code from SID.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_summary?.serverName ?? _server?.name ?? 'Home'),
      ),
      body: _loading
          ? Center(child: _connectingVpn
              ? const Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Connecting VPN…')])
              : const CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!.message),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(onRefresh: _load, child: _content(_summary!)),
    );
  }
}
