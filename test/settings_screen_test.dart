import 'package:flutter_test/flutter_test.dart';
import 'package:sid_app/app.dart';
import 'package:sid_app/services/server_store.dart';

void main() {
  testWidgets('adds a server from a pairing code', (tester) async {
    await tester.pumpWidget(SidApp(store: ServerStore(MemoryKeyValueStore())));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')),
    );
    await tester.pump();
    expect(find.text('Not a SID pairing code'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      '{"v":1,"name":"Home SID","url":"http://10.0.0.59:8000",'
      '"key":"sidk_AbC123-_xyz"}',
    );
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home SID'), findsOneWidget);
    expect(find.text('http://10.0.0.59:8000'), findsOneWidget);
  });
}
