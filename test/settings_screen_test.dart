import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/app.dart';
import 'package:laika_app/screens/settings_screen.dart';
import 'package:laika_app/services/server_store.dart';

void main() {
  Future<void> openAddServerDialog(WidgetTester tester) async {
    await tester.pumpWidget(LaikaApp(store: ServerStore(MemoryKeyValueStore())));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
  }

  testWidgets('Add server dialog offers QR scanning', (tester) async {
    await openAddServerDialog(tester);

    expect(find.text('Scan QR code'), findsOneWidget);
  });

  testWidgets('a scanned pairing code adds a server', (tester) async {
    await openAddServerDialog(tester);

    final dialog = tester.state<AddServerDialogState>(
      find.byType(AddServerDialog),
    );
    await dialog.useScannedCode(
      '{"v":1,"name":"Home LAIka","url":"http://10.0.0.59:8000",'
      '"key":"laika_AbC123-_xyz"}',
    );
    await tester.pumpAndSettle();

    expect(find.text('Home LAIka'), findsOneWidget);
  });

  testWidgets('an invalid scanned code shows an error', (tester) async {
    await openAddServerDialog(tester);

    final dialog = tester.state<AddServerDialogState>(
      find.byType(AddServerDialog),
    );
    await dialog.useScannedCode('hello');
    await tester.pump();

    expect(find.text('Not a LAIka pairing code'), findsOneWidget);
  });

  testWidgets('adds a server from a pairing code', (tester) async {
    await openAddServerDialog(tester);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')),
    );
    await tester.pump();
    expect(find.text('Not a LAIka pairing code'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      '{"v":1,"name":"Home LAIka","url":"http://10.0.0.59:8000",'
      '"key":"laika_AbC123-_xyz"}',
    );
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home LAIka'), findsOneWidget);
    expect(find.text('http://10.0.0.59:8000'), findsOneWidget);
  });
}
