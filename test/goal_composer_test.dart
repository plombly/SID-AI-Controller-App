import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sid_app/api/sid_api.dart';
import 'package:sid_app/models/sid_server.dart';
import 'package:sid_app/screens/goal_composer_screen.dart';

SidServer _server() => SidServer(
  id: 'sid', name: 'SID', url: 'http://sid.test', key: 'key',
);

Widget _host(SidApi api) => MaterialApp(
  home: Scaffold(
    body: Builder(builder: (context) => ElevatedButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => GoalComposerScreen(
          projectId: 'sid-app', projectName: 'SID App', api: api,
        ),
      )),
      child: const Text('Open'),
    )),
  ),
);

http.Response _json(Object body, [int status = 202]) =>
    http.Response(jsonEncode(body), status);

void main() {
  testWidgets('sends a goal, pops, and shows the started snackbar', (tester) async {
    late Map<String, dynamic> posted;
    final api = SidApi(_server(), client: MockClient((request) async {
      posted = jsonDecode(request.body) as Map<String, dynamic>;
      return _json({'id': 'goal'});
    }));
    await tester.pumpWidget(_host(api));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Fix the menu');
    await tester.pump();
    await tester.tap(find.text('Small change (one step)'));
    await tester.ensureVisible(find.text('Send as written'));
    await tester.tap(find.text('Send as written'));
    await tester.pumpAndSettle();

    expect(posted.keys.toSet(), {'goal', 'atomic', 'request_id'});
    expect(posted['goal'], 'Fix the menu');
    expect(posted['atomic'], isTrue);
    expect(find.text('Started. SID is on it.'), findsOneWidget);
  });

  testWidgets('plans through questions and submits the edited brief', (tester) async {
    final requests = <http.Request>[];
    final api = SidApi(_server(), client: MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/assistant')) {
        return _json({'id': '0123456789abcdef', 'project_id': 'sid-app', 'status': 'questions', 'questions': [{'question': 'Which key?', 'options': ['Esc', 'P']}], 'brief': null, 'error': '', 'goal_id': ''});
      }
      if (request.url.path.endsWith('/reply')) {
        return _json({'id': '0123456789abcdef', 'project_id': 'sid-app', 'status': 'brief', 'questions': [], 'brief': {'title': 'Pause menu', 'summary': 'Adds a pause menu.', 'goal': 'Add a pause menu.', 'atomic': true}, 'error': '', 'goal_id': ''});
      }
      return _json({'id': 'goal'});
    }));
    await tester.pumpWidget(_host(api));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Add pause menu');
    await tester.pump();
    await tester.ensureVisible(find.text('Plan it with me'));
    await tester.tap(find.text('Plan it with me'));
    await tester.pumpAndSettle();
    expect(find.text('Which key?'), findsOneWidget);
    await tester.tap(find.text('Esc'));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Pause menu'), findsOneWidget);
    expect(find.text('Add a pause menu.'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.ensureVisible(fields.last);
    await tester.enterText(fields.last, 'Use a pause overlay');
    await tester.ensureVisible(find.text('Start this goal'));
    await tester.tap(find.text('Start this goal'));
    await tester.pumpAndSettle();

    final reply = requests.firstWhere((request) => request.url.path.endsWith('/reply'));
    expect(jsonDecode(reply.body), {'answers': ['Esc']});
    final submit = requests.firstWhere((request) => request.url.path.endsWith('/submit'));
    expect((jsonDecode(submit.body) as Map)['goal'], 'Use a pause overlay');
    expect((jsonDecode(submit.body) as Map)['atomic'], isTrue);
  });

  testWidgets('failed session offers sending the idea as written', (tester) async {
    final api = SidApi(_server(), client: MockClient((request) async {
      if (request.url.path.endsWith('/assistant')) {
        return _json({'id': '0123456789abcdef', 'project_id': 'sid-app', 'status': 'failed', 'questions': [], 'brief': null, 'error': 'Could not read the project', 'goal_id': ''});
      }
      return _json({'id': 'goal'});
    }));
    await tester.pumpWidget(_host(api));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Do something');
    await tester.pump();
    await tester.ensureVisible(find.text('Plan it with me'));
    await tester.tap(find.text('Plan it with me'));
    await tester.pumpAndSettle();
    expect(find.text('Could not read the project'), findsOneWidget);
    expect(find.text('Send my idea as written'), findsOneWidget);
  });

  testWidgets('polls a queued session and can be disposed cleanly', (tester) async {
    final api = SidApi(_server(), client: MockClient((request) async {
      if (request.url.path.endsWith('/assistant')) {
        return _json({'id': '0123456789abcdef', 'project_id': 'sid-app', 'status': 'queued', 'questions': [], 'brief': null, 'error': '', 'goal_id': ''});
      }
      return _json({'id': '0123456789abcdef', 'project_id': 'sid-app', 'status': 'brief', 'questions': [], 'brief': {'title': 'A brief', 'summary': 'Summary', 'goal': 'Goal', 'atomic': false}, 'error': '', 'goal_id': ''}, 200);
    }));
    await tester.pumpWidget(_host(api));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Think about it');
    await tester.pump();
    await tester.ensureVisible(find.text('Plan it with me'));
    await tester.tap(find.text('Plan it with me'));
    await tester.pump();
    expect(find.text('Reading the project and thinking…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('A brief'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
