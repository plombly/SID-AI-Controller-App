import 'package:flutter/material.dart';

export 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/server_store.dart';
import 'vpn/vpn_controller.dart';
import 'vpn/vpn_store.dart';

class LaikaApp extends StatelessWidget {
  LaikaApp({super.key, ServerStore? store, VpnController? vpn, VpnStore? vpnStore})
      : store = store ?? ServerStore(const SecureKeyValueStore()),
        vpnStore = vpnStore ?? VpnStore(store?.store ?? const SecureKeyValueStore()),
        vpn = vpn ?? OpenVpnController();

  final ServerStore store;
  final VpnStore vpnStore;
  final VpnController vpn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LAIka',
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
      home: HomeShell(store: store, vpnStore: vpnStore, vpn: vpn),
    );
  }
}
