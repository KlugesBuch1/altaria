import 'package:material_ui/material_ui.dart';

/// After-hours oxblood: near-black red for large fields, warm parchment for
/// text, dusty rose for interaction, deep wine for fills and the monogram.
const ink = Color(0xFF160A0A);
const panel = Color(0xFF241111);
const panelHigh = Color(0xFF321515);
const wine = Color(0xFF5A1414);
const rose = Color(0xFFC88C80);
const cream = Color(0xFFEADFD3);
const muted = Color(0xFFB7A69B);

ThemeData buildAltariaTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: rose,
    onPrimary: Color(0xFF2A0B0B),
    primaryContainer: wine,
    onPrimaryContainer: cream,
    secondary: cream,
    onSecondary: Color(0xFF2A0B0B),
    secondaryContainer: panelHigh,
    onSecondaryContainer: cream,
    tertiary: wine,
    onTertiary: cream,
    error: Color(0xFFE8A79C),
    onError: Color(0xFF2A0B0B),
    surface: panel,
    onSurface: cream,
    surfaceContainerHighest: panelHigh,
    onSurfaceVariant: muted,
    outline: Color(0xFF3D2421),
    outlineVariant: Color(0xFF2A1816),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: cream,
    onInverseSurface: ink,
  );

  final base = ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: ink,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: cream, displayColor: cream)
        .copyWith(
          displaySmall: base.textTheme.displaySmall?.copyWith(
            fontFamily: 'Jost',
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontFamily: 'Jost',
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontFamily: 'Jost',
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          labelSmall: base.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: cream,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: panel,
      surfaceTintColor: Colors.transparent,
      indicatorColor: wine,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? cream : muted, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? cream : muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      hintStyle: const TextStyle(color: muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF3D2421)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: rose, width: 1.2),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: rose,
      inactiveTrackColor: const Color(0xFF3A2420),
      thumbColor: cream,
      overlayColor: rose.withValues(alpha: 0.15),
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: wine,
        foregroundColor: cream,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: wine,
      contentTextStyle: const TextStyle(color: cream),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2E1A17),
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: rose),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: rose,
      selectionColor: Color(0x665A1414),
      selectionHandleColor: rose,
    ),
  );
}
