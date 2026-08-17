import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF4F46E5); // indigo
  static const onColor = Color(0xFF10B981); // green
  static const offColor = Color(0xFF6B7280); // gray
  static const errorColor = Color(0xFFEF4444); // red
  static const disconnectedColor = Color(0xFFF59E0B); // amber
}

class AppTheme {
  static ThemeData light() {
    // Use the ThemeData.from constructor which accepts useMaterial3 instead of
    // setting the deprecated useMaterial3 flag on copyWith.
    final cs = ColorScheme.fromSeed(seedColor: AppColors.primary);
    final base = ThemeData.from(colorScheme: cs, useMaterial3: true);

    return base.copyWith(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: const Color(0xFFF5F7FF),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        headlineMedium: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(fontSize: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 66,
        indicatorColor: AppColors.primary.withAlpha((0.12 * 255).round()),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : Colors.grey.shade600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? AppColors.primary : Colors.grey.shade500);
        }),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.onColor;
          return Colors.grey.shade300;
        }),
      ),
    );
  }

  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.dark);
    final base = ThemeData.from(colorScheme: cs, useMaterial3: true);
    return base.copyWith();
  }
}
