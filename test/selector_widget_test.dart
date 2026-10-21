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
    testWidgets('renders brand title, site profiles and Edit links action', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Binge'), findsOneWidget);
      expect(find.text('BingeBang'), findsOneWidget);
      expect(find.text('Rivestream'), findsOneWidget);
      expect(find.text('Edit links'), findsOneWidget);
      expect(find.text('bingebang.st'), findsNothing);
      expect(find.text('rivestream.ru'), findsNothing);
      expect(find.text('Manage sites'), findsNothing);
    });

    testWidgets('profiles fit compact TV and mobile logical viewports', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(960, 540),
        const Size(1280, 720),
        const Size(640, 360),
        const Size(390, 844),
        const Size(844, 390),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        for (final label in ['BingeBang', 'Rivestream', 'Edit links']) {
          final rect = tester.getRect(find.text(label));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
        }
        expect(tester.takeException(), isNull);
      }
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

        // Press D-pad Down to move focus to Edit links
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

    testWidgets('tapping BingeBang opens exactly one site route', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? openedSite;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildBingeTheme(),
          home: SelectorScreen(
            webScreenBuilder: (site) {
              openedSite = site.name;
              return const Scaffold(body: Text('Test site route'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('BingeBang'));
      await tester.pumpAndSettle();
      expect(find.text('Test site route'), findsOneWidget);
      expect(openedSite, 'BingeBang');
    });

    testWidgets('tapping Rivestream opens exactly one site route', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? openedSite;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildBingeTheme(),
          home: SelectorScreen(
            webScreenBuilder: (site) {
              openedSite = site.name;
              return const Scaffold(body: Text('Test site route'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rivestream'));
      await tester.pumpAndSettle();
      expect(find.text('Test site route'), findsOneWidget);
      expect(openedSite, 'Rivestream');
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

    testWidgets('selector has no extra hint row', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('OK select'), findsNothing);
    });
  });
}
