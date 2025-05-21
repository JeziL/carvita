import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF3A7BD5);
  static const Color secondaryBlue = Color(0xFF00D2FF);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textBlack = Color(0xFF000000);
  static const Color textWhite = Color(0xFFFFFFFF);

  static const Color iconOnPrimary = Color(0xFFFFFFFF);
  static const Color iconOnWhite = Color(0xFF3A7BD5);

  static const Color urgentReminderText = Color(0xFFD32F2F);
  static const Color fabBackground = Color(0xFFFFFFFF);
  static const Color fabIcon = primaryBlue;

  static const Gradient primaryGradient = LinearGradient(
    colors: [primaryBlue, secondaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color bottomNavBackground = Color.fromRGBO(255, 255, 255, 0.95);
  static const Color bottomNavActiveIcon = primaryBlue;
  static const Color bottomNavInactiveIcon = Color(0xFF000000);

  static const Color statusBarColor = Color.fromRGBO(0, 0, 0, 0.1);
  static const Color quickActionBackground = Color.fromRGBO(255, 255, 255, 0.2);
}
