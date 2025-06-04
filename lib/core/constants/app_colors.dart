import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF3A7BD5);
  static const Color secondaryBlue = Color(0xFF00D2FF);

  static const Color urgentReminderText = Color(0xFFD32F2F);

  static Color darken(Color color, [double amount = .1]) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
