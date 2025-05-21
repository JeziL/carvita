import 'package:flutter/material.dart';

import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';

class MainBottomNavigationBar extends StatelessWidget {
  final int currentIndex;

  const MainBottomNavigationBar({super.key, required this.currentIndex});

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    String route;
    switch (index) {
      case 0:
        route = AppRoutes.dashboardRoute;
        break;
      case 1:
        route = AppRoutes.vehicleListRoute;
        break;
      case 2:
        route = AppRoutes.upcomingMaintenanceRoute;
        break;
      case 3:
        route = AppRoutes.settingsRoute;
        break;
      default:
        return;
    }
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bottomNavBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => _onItemTapped(context, index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.bottomNavActiveIcon,
          unselectedItemColor: AppColors.bottomNavInactiveIcon,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: AppLocalizations.of(context)!.navDashboard,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car_outlined),
              activeIcon: Icon(Icons.directions_car),
              label: AppLocalizations.of(context)!.navVehicles,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_note_outlined),
              activeIcon: Icon(Icons.event_note),
              label: AppLocalizations.of(context)!.navMaintenanceList,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: AppLocalizations.of(context)!.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}
