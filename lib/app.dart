import 'package:flutter/material.dart';

export 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/server_store.dart';

class SidApp extends StatelessWidget {
  SidApp({super.key, ServerStore? store})
      : store = store ?? ServerStore(const SecureKeyValueStore());

  final ServerStore store;

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
      home: HomeShell(store: store),
    );
  }
}
