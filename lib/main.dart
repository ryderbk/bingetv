import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/selector_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const BingeApp());
}

class BingeApp extends StatelessWidget {
  const BingeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Binge',
      debugShowCheckedModeBanner: false,
      theme: buildBingeTheme(),
      home: const SelectorScreen(),
    );
  }
}
