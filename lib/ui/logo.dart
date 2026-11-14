import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The app icon: a single lowercase a from the wordmark face. Cream on wine.
/// It is deliberately a letter, not a symbol.
class AltariaMonogram extends StatelessWidget {
  const AltariaMonogram({
    super.key,
    this.size = 48,
    this.background = wine,
    this.foreground = cream,
    this.semanticLabel,
  });

  final double size;
  final Color? background;
  final Color foreground;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final letter = SizedBox.square(
      dimension: size,
      child: ColoredBox(
        color: background ?? Colors.transparent,
        child: Center(
          child: Text(
            'a',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Jost',
              fontWeight: FontWeight.w700,
              fontSize: size * 0.74,
              height: 1,
              letterSpacing: -size * 0.02,
              color: foreground,
            ),
          ),
        ),
      ),
    );
    final label = semanticLabel;
    if (label == null) return letter;
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(child: letter),
    );
  }
}
