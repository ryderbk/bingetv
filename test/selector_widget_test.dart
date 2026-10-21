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
    testWidgets('renders only the two site profiles', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Binge'), findsOneWidget);
      expect(find.text('BingeBang'), findsOneWidget);
      expect(find.text('Rivestream'), findsOneWidget);
      expect(find.byType(TvFocusable), findsNWidgets(2));
      expect(find.text('Edit links'), findsNothing);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Remote Test'), findsNothing);
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

        for (final label in ['BingeBang', 'Rivestream']) {
          final rect = tester.getRect(find.text(label));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('one D-pad press moves to one adjacent site', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      final profiles = tester.widgetList<TvFocusable>(find.byType(TvFocusable));
      final focusNodes = profiles.map((profile) => profile.focusNode!).toList();

      expect(focusNodes[0].hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(focusNodes[0].hasFocus, isFalse);
      expect(focusNodes[1].hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(focusNodes[0].hasFocus, isTrue);
      expect(find.byType(SelectorScreen), findsOneWidget);
    });

    testWidgets('Menu opens the editor for the focused site', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();

      expect(find.text('Edit BingeBang'), findsOneWidget);
      expect(find.text('Website name'), findsOneWidget);
      expect(find.text('Website URL'), findsOneWidget);
      expect(find.text('Remote Test'), findsNothing);
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
