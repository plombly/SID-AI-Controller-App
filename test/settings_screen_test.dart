import 'package:flutter_test/flutter_test.dart';
import 'package:sid_app/app.dart';
import 'package:sid_app/screens/settings_screen.dart';
import 'package:sid_app/services/server_store.dart';

void main() {
  Future<void> openAddServerDialog(WidgetTester tester) async {
    await tester.pumpWidget(SidApp(store: ServerStore(MemoryKeyValueStore())));
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
      '{"v":1,"name":"Home SID","url":"http://10.0.0.59:8000",'
      '"key":"sidk_AbC123-_xyz"}',
    );
    await tester.pumpAndSettle();

    expect(find.text('Home SID'), findsOneWidget);
  });

  testWidgets('an invalid scanned code shows an error', (tester) async {
    await openAddServerDialog(tester);

    final dialog = tester.state<AddServerDialogState>(
      find.byType(AddServerDialog),
    );
    await dialog.useScannedCode('hello');
    await tester.pump();

    expect(find.text('Not a SID pairing code'), findsOneWidget);
  });

  testWidgets('adds a server from a pairing code', (tester) async {
    await openAddServerDialog(tester);

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
