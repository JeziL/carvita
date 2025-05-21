import 'package:flutter/material.dart';

import 'package:carvita/core/constants/app_colors.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primaryBlue,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: AppColors.statusBarColor,
      iconTheme: IconThemeData(color: AppColors.iconOnPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.textWhite,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 4,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.fabBackground,
      foregroundColor: AppColors.fabIcon,
      shape: CircleBorder(),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.textWhite,
      selectionColor: AppColors.secondaryBlue,
      selectionHandleColor: AppColors.secondaryBlue,
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: AppColors.textWhite.withValues(alpha: 0.7)),
      labelStyle: TextStyle(color: AppColors.textWhite.withValues(alpha: 0.9)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(
          color: AppColors.textWhite.withValues(alpha: 0.3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(
          color: AppColors.textWhite.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: AppColors.textWhite),
      ),
      filled: true,
      fillColor: AppColors.textWhite.withValues(alpha: 0.15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textBlack),
      bodyMedium: TextStyle(color: AppColors.textBlack),
      titleLarge: TextStyle(color: AppColors.textWhite),
      headlineSmall: TextStyle(
        color: AppColors.textWhite,
        fontSize: 28,
        fontWeight: FontWeight.w500,
      ),
      headlineMedium: TextStyle(
        color: AppColors.textWhite,
        fontSize: 22,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: TextStyle(
        color: AppColors.textWhite,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
    ).apply(bodyColor: AppColors.textBlack, displayColor: AppColors.textWhite),
  );
}
