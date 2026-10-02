import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sid_app/api/models.dart';
import 'package:sid_app/api/sid_api.dart';
import 'package:sid_app/models/sid_server.dart';
import 'package:flutter_test/flutter_test.dart';

const infoBody = '''
{"server_name":"SID","api_version":1,"min_api_version":1,"sid_commit":"342fa8f","server_time":1790898447.05,"device":{"id":"a1b2c3d4e5f6","name":"Dylan's phone"},"token_required":true,"device_actions":["extend","network_always","network_deny","network_once","reject"]}
''';

const summaryBody = '''
{"server_name":"SID","health":{"status":"ok","age_seconds":6},"needs_you":{"ready":[{"id":"1d2ab755","title":"Add a pause menu","project_id":"sid-app","status":"awaiting_review","integrated_candidate_commit":"f28dfc86c6372b77936d87a6271164c6c428763f"}],"stuck":[{"id":"9f00aa11","title":"Stripe checkout","project_id":"shop","status":"needs_human","needs_human_kind":"network","network_request_step":"tests","network_request_reason":"getaddrinfo EAI_AGAIN registry.npmjs.org"}]},"in_progress":[{"id":"962cf32b","project_id":"sid-app","status":"running","summary":"SID App: servers","updated_at":"1790898447.05","progress":{"total":3,"completed":1}}],"recent":[{"id":"3f9df88c","project_id":"sid-app","status":"completed","summary":"Create the SID App skeleton","updated_at":"1790898440.90","progress":{"total":1,"completed":1}}],"projects":[{"id":"sid","name":"SID AI Command Center","importance":"high","status":"active","parent":"","counts":{"jobs_running":1,"jobs_queued":0,"jobs_awaiting_approval":0,"jobs_needs_human":0}},{"id":"sid-app","name":"SID App","importance":"high","status":"active","parent":"sid","counts":{"jobs_running":0,"jobs_queued":2,"jobs_awaiting_approval":1,"jobs_needs_human":0}}]}
''';

const projectBody = '''
{"id":"sid-app","name":"SID App","status":"active","importance":"high","parent":"sid","parent_name":"SID AI Command Center","project_type":{"type":"mobile_cross"},"children":[{"id":"x","name":"X","status":"active"}],"goals":[{"id":"83aa0cee","status":"completed","summary":"SID App: servers","progress":{"total":1,"completed":1}}],"jobs":[{"id":"20792a55","title":"Servers: pairing, secure storage, settings UI, tests","status":"merged"}]}
''';

const sessionBody = '''
{"id":"0123456789abcdef","project_id":"sid-app","status":"questions","questions":[{"question":"Which key?","options":["Esc","P"]}],"brief":null,"error":"","goal_id":""}
''';

SidServer server({String url = 'http://sid.test'}) =>
    SidServer(id: 'sid', name: 'SID', url: url, key: 'secret-key');

void main() {
  test('info parses and sends authentication headers', () async {
    late http.Request request;
    final api = SidApi(
      server(),
      client: MockClient((received) async {
        request = received;
        return http.Response(infoBody, 200);
      }),
    );

    final result = await api.info();

    expect(result.serverName, 'SID');
    expect(result.apiVersion, 1);
    expect(result.minApiVersion, 1);
    expect(result.sidCommit, '342fa8f');
    expect(result.deviceName, "Dylan's phone");
    expect(request.headers['authorization'], 'Bearer secret-key');
    expect(request.headers['accept'], 'application/json');
  });

  test('trailing slash is removed from info URL', () async {
    late Uri requested;
    final api = SidApi(
      server(url: 'http://sid.test/'),
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(infoBody, 200);
      }),
    );

    await api.info();

    expect(requested.path, '/api/app/info');
  });

  test('summary parses jobs, goals, and projects', () async {
    final api = SidApi(
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
    expect(result.recent.single.summary, 'Create the SID App skeleton');
    expect(result.projects[1].parent, 'sid');
    expect(result.projects[1].queued, 2);
    expect(result.projects[1].awaitingApproval, 1);
    expect(result.projects.first.parent, '');
  });

  test('missing lists parse as empty', () async {
    final api = SidApi(
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
    Future<SidApiException> errorFor(
      Future<http.Response> Function(http.Request) handler,
    ) async {
      final api = SidApi(server(), client: MockClient(handler));
      try {
        await api.info();
        throw StateError('expected an exception');
      } on SidApiException catch (error) {
        return error;
      }
    }

    final unauthorized = await errorFor((_) async => http.Response('', 401));
    expect(
      unauthorized.message,
      "This phone's key was revoked or is not valid. Pair it again from SID → Settings → Phones & apps.",
    );
    expect(unauthorized.statusCode, 401);
    final serverError = await errorFor((_) async => http.Response('', 500));
    expect(serverError.message, 'SID answered with HTTP 500');
    expect(serverError.statusCode, 500);
    final invalidJson = await errorFor((_) async => http.Response('nope', 200));
    expect(invalidJson.message, 'SID sent an unexpected answer');
    final connection = await errorFor(
      (_) async => throw http.ClientException('offline'),
    );
    expect(
      connection.message,
      "Can't reach SID at http://sid.test. Is the VPN connected?",
    );
  });

  test('checkCompatible validates API version before pairing', () async {
    final newer = jsonDecode(infoBody) as Map<String, dynamic>;
    newer['min_api_version'] = 2;
    final newerApi = SidApi(
      server(),
      client: MockClient((_) async => http.Response(jsonEncode(newer), 200)),
    );
    expect(
      newerApi.checkCompatible(),
      throwsA(
        isA<SidApiException>().having(
          (error) => error.message,
          'message',
          'This SID server needs a newer app (API version 2)',
        ),
      ),
    );

    final unpaired = jsonDecode(infoBody) as Map<String, dynamic>;
    unpaired['device'] = null;
    final unpairedApi = SidApi(
      server(),
      client: MockClient((_) async => http.Response(jsonEncode(unpaired), 200)),
    );
    expect(
      unpairedApi.checkCompatible(),
      throwsA(
        isA<SidApiException>().having(
          (error) => error.message,
          'message',
          'This phone is not paired with SID. Pair it again from SID → Settings → Phones & apps.',
        ),
      ),
    );
  });

  test('project parses detail and encodes id with limit', () async {
    late http.Request request;
    final api = SidApi(
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
    expect(result.parentName, 'SID AI Command Center');
    expect(result.type, 'mobile_cross');
    expect(result.children.single.name, 'X');
    expect(result.goals.single.completed, 1);
    expect(result.jobs.single.status, 'merged');
  });

  test('project and assistant models use empty defaults', () async {
    final api = SidApi(
      server(),
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    final project = await api.project('sid-app');
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
    final api = SidApi(
      server(),
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/projects/sid-app') {
          return http.Response('{"id":"session"}', 202);
        }
        if (request.url.path.endsWith('/submit') ||
            request.url.path.endsWith('/goals')) {
          return http.Response('{"id":"goal-id"}', 202);
        }
        return http.Response(sessionBody, 202);
      }),
    );

    expect(await api.submitGoal('sid-app', 'Do it'), 'goal-id');
    await api.startAssistant('sid-app', 'An idea');
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
    expect(requests[0].url.path, '/api/projects/sid-app/goals');
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

  test('detail responses become SidApiException messages', () async {
    for (final status in <int>[409, 422]) {
      final api = SidApi(
        server(),
        client: MockClient(
          (_) async => http.Response('{"detail":"nope-$status"}', status),
        ),
      );
      await expectLater(
        api.submitGoal('sid-app', 'goal'),
        throwsA(
          isA<SidApiException>().having(
            (error) => error.message,
            'message',
            'nope-$status',
          ),
        ),
      );
    }
  });
}
