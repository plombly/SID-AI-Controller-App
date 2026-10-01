import 'package:flutter/material.dart';

export 'package:flutter/material.dart';

import 'screens/home_shell.dart';

class SidApp extends StatelessWidget {
  const SidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SID',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B9DFF)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B9DFF),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const HomeShell(),
    );
  }
}
