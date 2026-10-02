int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value is String ? value : '') ?? 0;
}

double _doubleValue(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value is String ? value : '') ?? 0;
}

String _stringValue(Object? value) => value is String ? value : '';

String? _nullableString(Object? value) => value is String ? value : null;

Map<String, dynamic> _mapValue(Object? value) {
  if (value is! Map) {
    return <String, dynamic>{};
  }
  return <String, dynamic>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) {
    return <Map<String, dynamic>>[];
  }
  return value.whereType<Map>().map(_mapValue).toList();
}

class AppInfo {
  const AppInfo({
    required this.serverName,
    required this.apiVersion,
    required this.minApiVersion,
    required this.sidCommit,
    required this.deviceName,
  });

  final String serverName;
  final int apiVersion;
  final int minApiVersion;
  final String sidCommit;
  final String? deviceName;

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    final device = _mapValue(json['device']);
    return AppInfo(
      serverName: _stringValue(json['server_name']),
      apiVersion: _intValue(json['api_version']),
      minApiVersion: _intValue(json['min_api_version']),
      sidCommit: _stringValue(json['sid_commit']),
      deviceName: json['device'] == null
          ? null
          : _nullableString(device['name']),
    );
  }
}

class JobItem {
  const JobItem({
    required this.id,
    required this.title,
    required this.projectId,
    required this.status,
    required this.needsHumanKind,
    required this.networkRequestStep,
    required this.networkRequestReason,
    required this.integratedCandidateCommit,
  });

  final String id;
  final String title;
  final String projectId;
  final String status;
  final String? needsHumanKind;
  final String? networkRequestStep;
  final String? networkRequestReason;
  final String? integratedCandidateCommit;

  bool get wantsInternet => needsHumanKind == 'network';

  factory JobItem.fromJson(Map<String, dynamic> json) => JobItem(
    id: _stringValue(json['id']),
    title: _stringValue(json['title']),
    projectId: _stringValue(json['project_id']),
    status: _stringValue(json['status']),
    needsHumanKind: _nullableString(json['needs_human_kind']),
    networkRequestStep: _nullableString(json['network_request_step']),
    networkRequestReason: _nullableString(json['network_request_reason']),
    integratedCandidateCommit: _nullableString(
      json['integrated_candidate_commit'],
    ),
  );
}

class GoalItem {
  const GoalItem({
    required this.id,
    required this.projectId,
    required this.status,
    required this.summary,
    required this.total,
    required this.completed,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String status;
  final String summary;
  final int total;
  final int completed;
  final double updatedAt;

  factory GoalItem.fromJson(Map<String, dynamic> json) {
    final progress = _mapValue(json['progress']);
    return GoalItem(
      id: _stringValue(json['id']),
      projectId: _stringValue(json['project_id']),
      status: _stringValue(json['status']),
      summary: _stringValue(json['summary']),
      total: _intValue(progress['total']),
      completed: _intValue(progress['completed']),
      updatedAt: _doubleValue(json['updated_at']),
    );
  }
}

class ProjectRef {
  const ProjectRef({
    required this.id,
    required this.name,
    required this.status,
  });

  final String id;
  final String name;
  final String status;

  factory ProjectRef.fromJson(Map<String, dynamic> json) => ProjectRef(
    id: _stringValue(json['id']),
    name: _stringValue(json['name']),
    status: _stringValue(json['status']),
  );
}

class JobRef {
  const JobRef({required this.id, required this.title, required this.status});

  final String id;
  final String title;
  final String status;

  factory JobRef.fromJson(Map<String, dynamic> json) => JobRef(
    id: _stringValue(json['id']),
    title: _stringValue(json['title']),
    status: _stringValue(json['status']),
  );
}

class ProjectDetail {
  const ProjectDetail({
    required this.id,
    required this.name,
    required this.status,
    required this.importance,
    required this.parent,
    required this.parentName,
    required this.type,
    required this.children,
    required this.goals,
    required this.jobs,
  });

  final String id;
  final String name;
  final String status;
  final String importance;
  final String parent;
  final String parentName;
  final String type;
  final List<ProjectRef> children;
  final List<GoalItem> goals;
  final List<JobRef> jobs;

  factory ProjectDetail.fromJson(Map<String, dynamic> json) {
    final projectType = _mapValue(json['project_type']);
    return ProjectDetail(
      id: _stringValue(json['id']),
      name: _stringValue(json['name']),
      status: _stringValue(json['status']),
      importance: _stringValue(json['importance']),
      parent: _stringValue(json['parent']),
      parentName: _stringValue(json['parent_name']),
      type: _stringValue(projectType['type']),
      children: _mapList(json['children']).map(ProjectRef.fromJson).toList(),
      goals: _mapList(json['goals']).map(GoalItem.fromJson).toList(),
      jobs: _mapList(json['jobs']).map(JobRef.fromJson).toList(),
    );
  }
}

class AssistantQuestion {
  const AssistantQuestion({required this.question, required this.options});

  final String question;
  final List<String> options;

  factory AssistantQuestion.fromJson(Map<String, dynamic> json) =>
      AssistantQuestion(
        question: _stringValue(json['question']),
        options: json['options'] is List
            ? (json['options'] as List).whereType<String>().toList()
            : <String>[],
      );
}

class AssistantBrief {
  const AssistantBrief({
    required this.title,
    required this.summary,
    required this.goal,
    required this.atomic,
  });

  final String title;
  final String summary;
  final String goal;
  final bool atomic;

  factory AssistantBrief.fromJson(Map<String, dynamic> json) => AssistantBrief(
    title: _stringValue(json['title']),
    summary: _stringValue(json['summary']),
    goal: _stringValue(json['goal']),
    atomic: json['atomic'] is bool ? json['atomic'] as bool : false,
  );
}

class AssistantSession {
  const AssistantSession({
    required this.id,
    required this.projectId,
    required this.status,
    required this.questions,
    required this.brief,
    required this.error,
    required this.goalId,
  });

  final String id;
  final String projectId;
  final String status;
  final List<AssistantQuestion> questions;
  final AssistantBrief? brief;
  final String error;
  final String goalId;

  bool get working => status == 'queued' || status == 'thinking';

  factory AssistantSession.fromJson(Map<String, dynamic> json) =>
      AssistantSession(
        id: _stringValue(json['id']),
        projectId: _stringValue(json['project_id']),
        status: _stringValue(json['status']),
        questions: _mapList(json['questions'])
            .map(AssistantQuestion.fromJson)
            .toList(),
        brief: json['brief'] == null
            ? null
            : AssistantBrief.fromJson(_mapValue(json['brief'])),
        error: _stringValue(json['error']),
        goalId: _stringValue(json['goal_id']),
      );
}

class ProjectItem {
  const ProjectItem({
    required this.id,
    required this.name,
    required this.importance,
    required this.status,
    required this.parent,
    required this.running,
    required this.queued,
    required this.awaitingApproval,
    required this.needsHuman,
  });

  final String id;
  final String name;
  final String importance;
  final String status;
  final String parent;
  final int running;
  final int queued;
  final int awaitingApproval;
  final int needsHuman;

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    final counts = _mapValue(json['counts']);
    return ProjectItem(
      id: _stringValue(json['id']),
      name: _stringValue(json['name']),
      importance: _stringValue(json['importance']),
      status: _stringValue(json['status']),
      parent: _stringValue(json['parent']),
      running: _intValue(counts['jobs_running']),
      queued: _intValue(counts['jobs_queued']),
      awaitingApproval: _intValue(counts['jobs_awaiting_approval']),
      needsHuman: _intValue(counts['jobs_needs_human']),
    );
  }
}

class Summary {
  const Summary({
    required this.serverName,
    required this.healthStatus,
    required this.healthAgeSeconds,
    required this.ready,
    required this.stuck,
    required this.inProgress,
    required this.recent,
    required this.projects,
  });

  final String serverName;
  final String healthStatus;
  final int? healthAgeSeconds;
  final List<JobItem> ready;
  final List<JobItem> stuck;
  final List<GoalItem> inProgress;
  final List<GoalItem> recent;
  final List<ProjectItem> projects;

  factory Summary.fromJson(Map<String, dynamic> json) {
    final health = _mapValue(json['health']);
    final needsYou = _mapValue(json['needs_you']);
    return Summary(
      serverName: _stringValue(json['server_name']),
      healthStatus: _stringValue(health['status']),
      healthAgeSeconds: health['age_seconds'] == null
          ? null
          : _intValue(health['age_seconds']),
      ready: _mapList(needsYou['ready']).map(JobItem.fromJson).toList(),
      stuck: _mapList(needsYou['stuck']).map(JobItem.fromJson).toList(),
      inProgress: _mapList(json['in_progress']).map(GoalItem.fromJson).toList(),
      recent: _mapList(json['recent']).map(GoalItem.fromJson).toList(),
      projects: _mapList(json['projects']).map(ProjectItem.fromJson).toList(),
    );
  }
}
