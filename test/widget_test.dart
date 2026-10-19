import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:binge/main.dart';

void main() {
  testWidgets('shows the Binge site selector', (tester) async {
    await tester.pumpWidget(const BingeApp());
    await tester.pump();
    expect(find.byType(BingeApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
