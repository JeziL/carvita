import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:carvita/presentation/navigation/main_navigation_controller.dart';
import 'package:carvita/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:carvita/presentation/screens/maintenance/upcoming_maintenance_list_screen.dart';
import 'package:carvita/presentation/screens/settings/settings_screen.dart';
import 'package:carvita/presentation/screens/vehicle/vehicle_list_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0, this.tabs})
    : assert(tabs == null || tabs.length == 4);

  final int initialIndex;
  final List<Widget>? tabs;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _selectedIndex;
  late final List<Widget?> _tabs;
  MainNavigationController? _controller;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _tabs = List<Widget?>.filled(4, null);
    _ensureTabCreated(_selectedIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<MainNavigationController>();
    if (!identical(controller, _controller)) {
      _controller?.detach(_selectTab);
      _controller = controller;
      controller.attach(initialIndex: _selectedIndex, onSelected: _selectTab);
    }
  }

  @override
  void dispose() {
    _controller?.detach(_selectTab);
    super.dispose();
  }

  void _selectTab(int index) {
    if (!mounted || index == _selectedIndex || index < 0 || index > 3) return;
    setState(() {
      _selectedIndex = index;
      _ensureTabCreated(index);
    });
  }

  void _ensureTabCreated(int index) {
    final providedTabs = widget.tabs;
    if (providedTabs != null) {
      _tabs[index] ??= providedTabs[index];
      return;
    }
    _tabs[index] ??= switch (index) {
      0 => const DashboardScreen(key: PageStorageKey('dashboard-tab')),
      1 => const VehicleListScreen(key: PageStorageKey('vehicles-tab')),
      2 => const UpcomingMaintenanceListScreen(
        key: PageStorageKey('upcoming-tab'),
      ),
      3 => const SettingsScreen(key: PageStorageKey('settings-tab')),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedIndex != 0) {
          _controller?.selectTab(0);
        }
      },
      child: IndexedStack(
        key: const ValueKey('main-shell'),
        index: _selectedIndex,
        children: [
          for (var index = 0; index < _tabs.length; index++)
            KeyedSubtree(
              key: ValueKey('main-tab-$index'),
              child: _tabs[index] ?? const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
