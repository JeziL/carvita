import 'package:flutter/material.dart';

import 'package:carvita/core/constants/app_colors.dart';

class AppTheme {
  static ThemeData getThemeData(
    ColorScheme colorScheme,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;

    final Gradient primaryGradient = LinearGradient(
      colors: [
        isDark
            ? AppColors.darken(colorScheme.primary, 0.1)
            : colorScheme.primary,
        isDark
            ? AppColors.darken(colorScheme.secondary, 0.1)
            : colorScheme.secondary,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      primaryColor: colorScheme.primary,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: colorScheme.surfaceContainer,
        iconTheme: IconThemeData(color: colorScheme.onPrimaryContainer),
        titleTextStyle: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        color: colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: const CircleBorder(),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.4),
        selectionHandleColor: colorScheme.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: colorScheme.onPrimary.withValues(alpha: 0.7),
        ),
        labelStyle: TextStyle(color: colorScheme.onPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(
            color: colorScheme.onPrimary.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(
            color: colorScheme.onPrimary.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: colorScheme.onPrimary),
        ),
        filled: true,
        fillColor: colorScheme.onPrimary.withValues(alpha: 0.15),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 13,
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: colorScheme.onSurface),
        bodyMedium: TextStyle(color: colorScheme.onSurface),
        titleLarge: TextStyle(color: colorScheme.onSurface),
        headlineSmall: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 28,
          fontWeight: FontWeight.w500,
        ),
        headlineMedium: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ).apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        elevation: 0,
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeExtensions(primaryGradient: primaryGradient),
      ],
    );
  }
}

@immutable
class AppThemeExtensions extends ThemeExtension<AppThemeExtensions> {
  const AppThemeExtensions({required this.primaryGradient});

  final Gradient primaryGradient;

  @override
  AppThemeExtensions copyWith({Gradient? primaryGradient}) {
    return AppThemeExtensions(
      primaryGradient: primaryGradient ?? this.primaryGradient,
    );
  }

  @override
  AppThemeExtensions lerp(ThemeExtension<AppThemeExtensions>? other, double t) {
    if (other is! AppThemeExtensions) {
      return this;
    }
    return AppThemeExtensions(
      primaryGradient:
          Gradient.lerp(primaryGradient, other.primaryGradient, t)!,
    );
  }
}
