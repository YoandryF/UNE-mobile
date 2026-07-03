import 'package:flutter/material.dart';

class AppTheme {
  static const _accent = Color(0xFF00D4FF);
  static const _accent2 = Color(0xFFE94560);
  static const _accent3 = Color(0xFF7C3AED);

  static ThemeData dark() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        secondary: _accent2,
        tertiary: _accent3,
        surface: Color(0xFF1A1A2E),
        surfaceContainerHighest: Color(0xFF16213E),
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF1A1A2E),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 44,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F3460).withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accent2,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: BorderSide(color: _accent.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _accent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1A1A2E),
        indicatorColor: _accent.withOpacity(0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const IconThemeData(color: _accent);
          return IconThemeData(color: Colors.white.withOpacity(0.5));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w600);
          return TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11);
        }),
      ),
      dividerColor: Colors.white.withOpacity(0.06),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData light() {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: const Color(0xFFF4F6F9),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0077CC),
        secondary: Color(0xFFD63050),
        tertiary: Color(0xFF6D28D9),
        surface: Colors.white,
        surfaceContainerHighest: Color(0xFFEEF2F7),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A1A2E),
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 44,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F4F8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0077CC), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFD63050),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0077CC),
          side: BorderSide(color: const Color(0xFF0077CC).withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF0077CC).withOpacity(0.1),
      ),
      dividerColor: Colors.black.withOpacity(0.06),
    );
  }

  // Gradient helpers
  static const accentGradient = LinearGradient(colors: [_accent, _accent3]);
  static const dangerGradient = LinearGradient(colors: [_accent2, Color(0xFFFF6B6B)]);
}

// Styled widgets
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;
  const GradientText(this.text, {super.key, this.style, this.gradient = AppTheme.accentGradient});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: (style ?? const TextStyle()).copyWith(color: Colors.white)),
    );
  }
}

class AccentCard extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  const AccentCard({super.key, required this.child, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const StatChip({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
