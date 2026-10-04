import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:laika_app/api/models.dart';
import 'package:laika_app/api/laika_api.dart';
import 'package:laika_app/models/laika_server.dart';
import 'package:flutter_test/flutter_test.dart';

const infoBody = '''
{"server_name":"LAIka","api_version":1,"min_api_version":1,"laika_commit":"342fa8f","server_time":1790898447.05,"device":{"id":"a1b2c3d4e5f6","name":"Dylan's phone"},"token_required":true,"device_actions":["extend","network_always","network_deny","network_once","reject"]}
''';

const summaryBody = '''
{"server_name":"LAIka","health":{"status":"ok","age_seconds":6},"needs_you":{"ready":[{"id":"1d2ab755","title":"Add a pause menu","project_id":"laika-app","status":"awaiting_review","integrated_candidate_commit":"f28dfc86c6372b77936d87a6271164c6c428763f"}],"stuck":[{"id":"9f00aa11","title":"Stripe checkout","project_id":"shop","status":"needs_human","needs_human_kind":"network","network_request_step":"tests","network_request_reason":"getaddrinfo EAI_AGAIN registry.npmjs.org"}]},"in_progress":[{"id":"962cf32b","project_id":"laika-app","status":"running","summary":"LAIka App: servers","updated_at":"1790898447.05","progress":{"total":3,"completed":1}}],"recent":[{"id":"3f9df88c","project_id":"laika-app","status":"completed","summary":"Create the LAIka App skeleton","updated_at":"1790898440.90","progress":{"total":1,"completed":1}}],"projects":[{"id":"sid","name":"LAIka AI Command Center","importance":"high","status":"active","parent":"","counts":{"jobs_running":1,"jobs_queued":0,"jobs_awaiting_approval":0,"jobs_needs_human":0}},{"id":"laika-app","name":"LAIka App","importance":"high","status":"active","parent":"sid","counts":{"jobs_running":0,"jobs_queued":2,"jobs_awaiting_approval":1,"jobs_needs_human":0}}]}
''';

const projectBody = '''
{"id":"laika-app","name":"LAIka App","status":"active","importance":"high","parent":"sid","parent_name":"LAIka AI Command Center","project_type":{"type":"mobile_cross"},"children":[{"id":"x","name":"X","status":"active"}],"goals":[{"id":"83aa0cee","status":"completed","summary":"LAIka App: servers","progress":{"total":1,"completed":1}}],"jobs":[{"id":"20792a55","title":"Servers: pairing, secure storage, settings UI, tests","status":"merged"}]}
''';

const sessionBody = '''
{"id":"0123456789abcdef","project_id":"laika-app","status":"questions","questions":[{"question":"Which key?","options":["Esc","P"]}],"brief":null,"error":"","goal_id":""}
''';

LaikaServer server({String url = 'http://laika.test'}) =>
    LaikaServer(id: 'sid', name: 'LAIka', url: url, key: 'secret-key');

void main() {
  test('info parses and sends authentication headers', () async {
    late http.Request request;
    final api = LaikaApi(
      server(),
      client: MockClient((received) async {
        request = received;
        return http.Response(infoBody, 200);
      }),
    );

    final result = await api.info();

    expect(result.serverName, 'LAIka');
    expect(result.apiVersion, 1);
    expect(result.minApiVersion, 1);
    expect(result.laikaCommit, '342fa8f');
    expect(result.deviceName, "Dylan's phone");
    expect(request.headers['authorization'], 'Bearer secret-key');
    expect(request.headers['accept'], 'application/json');
  });

  test('trailing slash is removed from info URL', () async {
    late Uri requested;
    final api = LaikaApi(
      server(url: 'http://laika.test/'),
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(infoBody, 200);
      }),
    );

    await api.info();

    expect(requested.path, '/api/app/info');
  });

  test('summary parses jobs, goals, and projects', () async {
    final api = LaikaApi(
      server(),
      client: MockClient((_) async => http.Response(summaryBody, 200)),
    );

    final result = await api.summary();

    expect(result.healthStatus, 'ok');
    expect(result.healthAgeSeconds, 6);
    expect(
      result.ready.single.integratedCandidateCommit,
      'f28dfc86c6372b77936d87a6271164c6c428763f',
    );
    expect(result.stuck.single.wantsInternet, isTrue);
    expect(result.stuck.single.networkRequestStep, 'tests');
    expect(
      result.stuck.single.networkRequestReason,
      'getaddrinfo EAI_AGAIN registry.npmjs.org',
    );
    expect(result.inProgress.single.total, 3);
    expect(result.inProgress.single.completed, 1);
    expect(result.inProgress.single.updatedAt, 1790898447.05);
    expect(result.recent.single.summary, 'Create the LAIka App skeleton');
    expect(result.projects[1].parent, 'sid');
    expect(result.projects[1].queued, 2);
    expect(result.projects[1].awaitingApproval, 1);
    expect(result.projects.first.parent, '');
  });

  test('missing lists parse as empty', () async {
    final api = LaikaApi(
      server(),
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    final result = await api.summary();

    expect(result.ready, isEmpty);
    expect(result.stuck, isEmpty);
    expect(result.inProgress, isEmpty);
    expect(result.recent, isEmpty);
    expect(result.projects, isEmpty);
  });

  test('HTTP, JSON, and connection errors use exact messages', () async {
    Future<LaikaApiException> errorFor(
      Future<http.Response> Function(http.Request) handler,
    ) async {
      final api = LaikaApi(server(), client: MockClient(handler));
      try {
        await api.info();
        throw StateError('expected an exception');
      } on LaikaApiException catch (error) {
        return error;
      }
    }

    final unauthorized = await errorFor((_) async => http.Response('', 401));
    expect(
      unauthorized.message,
      "This phone's key was revoked or is not valid. Pair it again from LAIka → Settings → Phones & apps.",
    );
    expect(unauthorized.statusCode, 401);
    final serverError = await errorFor((_) async => http.Response('', 500));
    expect(serverError.message, 'LAIka answered with HTTP 500');
    expect(serverError.statusCode, 500);
    final invalidJson = await errorFor((_) async => http.Response('nope', 200));
    expect(invalidJson.message, 'LAIka sent an unexpected answer');
    final connection = await errorFor(
      (_) async => throw http.ClientException('offline'),
    );
    expect(
      connection.message,
      "Can't reach LAIka at http://laika.test. Is the VPN or Tailscale connected?",
    );
  });

  test('checkCompatible validates API version before pairing', () async {
    final newer = jsonDecode(infoBody) as Map<String, dynamic>;
    newer['min_api_version'] = 2;
    final newerApi = LaikaApi(
      server(),
      client: MockClient((_) async => http.Response(jsonEncode(newer), 200)),
    );
    expect(
      newerApi.checkCompatible(),
      throwsA(
        isA<LaikaApiException>().having(
          (error) => error.message,
          'message',
          'This LAIka server needs a newer app (API version 2)',
        ),
      ),
    );

    final unpaired = jsonDecode(infoBody) as Map<String, dynamic>;
    unpaired['device'] = null;
    final unpairedApi = LaikaApi(
      server(),
      client: MockClient((_) async => http.Response(jsonEncode(unpaired), 200)),
    );
    expect(
      unpairedApi.checkCompatible(),
      throwsA(
        isA<LaikaApiException>().having(
          (error) => error.message,
          'message',
          'This phone is not paired with LAIka. Pair it again from LAIka → Settings → Phones & apps.',
        ),
      ),
    );
  });

  test('project parses detail and encodes id with limit', () async {
    late http.Request request;
    final api = LaikaApi(
      server(),
      client: MockClient((received) async {
        request = received;
        return http.Response(projectBody, 200);
      }),
    );

    final result = await api.project('sid app/1');

    expect(request.method, 'GET');
    expect(request.url.path, '/api/projects/sid%20app%2F1');
    expect(request.url.queryParameters['limit'], '25');
    expect(result.parentName, 'LAIka AI Command Center');
    expect(result.type, 'mobile_cross');
    expect(result.children.single.name, 'X');
    expect(result.goals.single.completed, 1);
    expect(result.jobs.single.status, 'merged');
  });

  test('project and assistant models use empty defaults', () async {
    final api = LaikaApi(
      server(),
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    final project = await api.project('laika-app');
    expect(project.name, '');
    expect(project.children, isEmpty);
    expect(project.goals, isEmpty);
    expect(project.jobs, isEmpty);

    final session = await api.assistant('sid');
    expect(session.brief, isNull);
    expect(session.questions, isEmpty);
    expect(session.working, isFalse);

    final briefSession = AssistantSession.fromJson({
      'status': 'brief',
      'brief': {
        'title': 'Pause menu',
        'summary': 'Adds a pause menu.',
        'goal': 'Build it',
        'atomic': true,
      },
    });
    expect(briefSession.brief!.title, 'Pause menu');
    expect(briefSession.brief!.atomic, isTrue);
  });

  test('new API calls use JSON methods, paths, and bodies', () async {
    final requests = <http.Request>[];
    final api = LaikaApi(
      server(),
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/projects/laika-app') {
          return http.Response('{"id":"session"}', 202);
        }
        if (request.url.path.endsWith('/submit') ||
            request.url.path.endsWith('/goals')) {
          return http.Response('{"id":"goal-id"}', 202);
        }
        return http.Response(sessionBody, 202);
      }),
    );

    expect(await api.submitGoal('laika-app', 'Do it'), 'goal-id');
    await api.startAssistant('laika-app', 'An idea');
    await api.answerAssistant('session', <String>['Esc']);
    await api.reviseAssistant('session', 'Make it smaller');
    expect(
      await api.submitAssistant('session', 'Goal', atomic: true),
      'goal-id',
    );
    await api.cancelAssistant('session');
    await api.assistant('session');

    expect(requests, hasLength(7));
    expect(requests[0].method, 'POST');
    expect(requests[0].url.path, '/api/projects/laika-app/goals');
    expect(requests[0].headers['content-type'], 'application/json');
    expect(jsonDecode(requests[0].body), containsPair('goal', 'Do it'));
    expect(jsonDecode(requests[0].body), containsPair('atomic', false));
    expect(jsonDecode(requests[1].body), containsPair('idea', 'An idea'));
    expect(
      jsonDecode(requests[2].body),
      containsPair('answers', <String>['Esc']),
    );
    expect(
      jsonDecode(requests[3].body),
      containsPair('feedback', 'Make it smaller'),
    );
    expect(requests[4].url.path, '/api/assistant/session/submit');
    expect(jsonDecode(requests[4].body), containsPair('atomic', true));
    expect(requests[5].url.path, '/api/assistant/session/cancel');
    expect(requests[6].method, 'GET');
    expect(requests[6].url.path, '/api/assistant/session');
  });

  test('detail responses become LaikaApiException messages', () async {
    for (final status in <int>[409, 422]) {
      final api = LaikaApi(
        server(),
        client: MockClient(
          (_) async => http.Response('{"detail":"nope-$status"}', status),
        ),
      );
      await expectLater(
        api.submitGoal('laika-app', 'goal'),
        throwsA(
          isA<LaikaApiException>().having(
            (error) => error.message,
            'message',
            'nope-$status',
          ),
        ),
      );
    }
  });
}
