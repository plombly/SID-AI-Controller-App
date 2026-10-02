import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'projects_screen.dart';
import 'settings_screen.dart';
import '../services/server_store.dart';
import '../vpn/vpn_controller.dart';
import '../vpn/vpn_store.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store, required this.vpnStore, required this.vpn});

  final ServerStore store;
  final VpnStore vpnStore;
  final VpnController vpn;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(store: widget.store, vpnStore: widget.vpnStore, vpn: widget.vpn),
      ProjectsScreen(store: widget.store, vpnStore: widget.vpnStore, vpn: widget.vpn),
      SettingsScreen(store: widget.store, vpnStore: widget.vpnStore, vpn: widget.vpn),
    ];

    return Scaffold(
      body: screens[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
