import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The name is the logo. Jost 700, tight, with one dusty-rose full stop.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  static const _style = TextStyle(
    fontFamily: 'Jost',
    fontWeight: FontWeight.w700,
    fontSize: 30,
    height: 1,
    letterSpacing: -1,
    color: cream,
  );

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'altaria'),
          TextSpan(
            text: '.',
            style: _style.copyWith(color: rose),
          ),
        ],
      ),
      style: _style,
      semanticsLabel: 'altaria',
    );
  }
}
