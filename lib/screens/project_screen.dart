import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/laika_api.dart';
import 'goal_composer_screen.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key, required this.projectId, required this.api});

  final String projectId;
  final LaikaApi api;

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  ProjectDetail? _project;
  LaikaApiException? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final project = await widget.api.project(widget.projectId);
      if (mounted) {
        setState(() {
          _project = project;
          _loading = false;
        });
      }
    } on LaikaApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = const LaikaApiException('Unable to load project.');
          _loading = false;
        });
      }
    }
  }

  Widget _section(String title, List<Widget> children, String empty) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (children.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(empty))
        else
          ...children,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final project = _project;
    return Scaffold(
      appBar: AppBar(title: Text(project?.name ?? 'Project')),
      body: _loading && project == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && project == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!.message),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  if (project!.parent.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Text('Part of ${project.parentName}'),
                    ),
                  _section('Goals', [
                    for (final goal in project.goals)
                      ListTile(
                        title: Text(goal.summary.split('\n').first),
                        subtitle: Text(
                          '${goal.completed} of ${goal.total} steps',
                        ),
                        trailing: Text(goal.status),
                      ),
                  ], 'No goals yet.'),
                  _section('Recent jobs', [
                    for (final job in project.jobs)
                      ListTile(
                        title: Text(job.title),
                        trailing: Text(job.status),
                      ),
                  ], 'No recent jobs.'),
                ],
              ),
            ),
      floatingActionButton: project == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GoalComposerScreen(
                      projectId: project.id,
                      projectName: project.name,
                      api: widget.api,
                    ),
                  ),
                );
                if (mounted) _load();
              },
              label: const Text('Give LAIka work'),
              icon: const Icon(Icons.add),
            ),
    );
  }
}
