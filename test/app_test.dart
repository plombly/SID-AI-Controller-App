import 'package:flutter_test/flutter_test.dart';
import 'package:sid_app/app.dart';
import 'package:sid_app/services/server_store.dart';

void main() {
  testWidgets('navigates between app sections', (WidgetTester tester) async {
    await tester.pumpWidget(SidApp(store: ServerStore(MemoryKeyValueStore())));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Home')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Projects'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Projects'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Settings'),
      ),
      findsOneWidget,
    );
  });
}
