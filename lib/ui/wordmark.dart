import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          'altaria',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: bone,
                fontSize: 26,
                letterSpacing: -0.8,
              ),
        ),
      ],
    );
  }
}
