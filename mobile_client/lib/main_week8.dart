// MCS4302 Week 8 entry point. Run with: flutter run -t lib/main_week8.dart
import 'package:flutter/material.dart';

import 'week8/week8_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Week8App());
}

class Week8App extends StatelessWidget {
  const Week8App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCS4302 Week 8',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const Week8Page(),
    );
  }
}
