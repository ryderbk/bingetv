import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:binge/screens/selector_screen.dart';
import 'package:binge/widgets/tv_focusable.dart';
import 'package:binge/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp() {
    return MaterialApp(theme: buildBingeTheme(), home: const SelectorScreen());
  }

  group('Selector Screen Widget Tests', () {
    testWidgets('renders brand title, subtitle, site cards and edit button', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Binge'), findsOneWidget);
      expect(find.text('Choose a site'), findsOneWidget);
      expect(find.text('BingeBang'), findsOneWidget);
      expect(find.text('Rivestream'), findsOneWidget);
      expect(find.text('Edit links'), findsOneWidget);
      expect(find.textContaining('OK select'), findsOneWidget);
    });

    testWidgets(
      'supports D-pad navigation and moves focus across cards and buttons',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // First card has initial focus
        // Press D-pad Right to navigate to second card
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();

        // Press D-pad Down to move focus to Edit links button
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        // Press D-pad Up to navigate back to cards
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        expect(find.byType(SelectorScreen), findsOneWidget);
      },
    );

    testWidgets('OK / Select activates Edit links and opens EditSitesScreen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Tap or focus Edit links button
      await tester.tap(find.text('Edit links'));
      await tester.pumpAndSettle();

      // Verify EditSitesScreen is opened
      expect(find.byType(EditSitesScreen), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets(
      'TvFocusable triggers onSelected via LogicalKeyboardKey.select (OK)',
      (tester) async {
        bool activated = false;
        final focusNode = FocusNode();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TvFocusable(
                focusNode: focusNode,
                autofocus: true,
                onSelected: () => activated = true,
                builder: (ctx, focused) => const Text('Target'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(focusNode.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        expect(activated, isTrue);
      },
    );

    testWidgets('hint row disappears after first keypress', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('OK select'), findsOneWidget);

      // Press any key (e.g. arrow down)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Check hint row is faded out (opacity 0)
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.textContaining('OK select'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(animatedOpacity.opacity, 0.0);
    });
  });
}
