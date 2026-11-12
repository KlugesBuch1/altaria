import 'package:material_ui/material_ui.dart';

const ink = Color(0xFF090D11);
const panel = Color(0xFF111820);
const panelHigh = Color(0xFF18212B);
const frost = Color(0xFFA6DDE8);
const ember = Color(0xFFFFB27A);
const bone = Color(0xFFF3F7F8);
const muted = Color(0xFF8A9AA6);

ThemeData buildAltariaTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: frost,
    onPrimary: Color(0xFF062229),
    primaryContainer: Color(0xFF16323A),
    onPrimaryContainer: frost,
    secondary: ember,
    onSecondary: Color(0xFF2A1505),
    secondaryContainer: Color(0xFF3A2418),
    onSecondaryContainer: ember,
    error: Color(0xFFFF8B8B),
    onError: Color(0xFF2B0505),
    surface: panel,
    onSurface: bone,
    surfaceContainerHighest: panelHigh,
    onSurfaceVariant: muted,
    outline: Color(0xFF2B3742),
    outlineVariant: Color(0xFF1D2731),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: bone,
    onInverseSurface: ink,
  );

  final base = ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: ink,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: bone, displayColor: bone)
        .copyWith(
          displaySmall: base.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -1.2,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
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
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: panel,
      surfaceTintColor: Colors.transparent,
      indicatorColor: frost.withValues(alpha: 0.12),
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
        borderSide: const BorderSide(color: Color(0xFF1C2833)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: frost, width: 1.2),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: frost,
      inactiveTrackColor: const Color(0xFF2A3742),
      thumbColor: bone,
      overlayColor: frost.withValues(alpha: 0.15),
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: panelHigh,
      contentTextStyle: const TextStyle(color: bone),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF1B2530),
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: frost),
  );
}
