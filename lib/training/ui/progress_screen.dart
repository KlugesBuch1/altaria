import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import 'widgets.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TrainingHeader(
            eyebrow: 'Train',
            title: 'Progress',
            subtitle: 'Records, body metrics, and the long line upward.',
          ),
          const SizedBox(height: 24),
          const EmptyPanel(
            icon: Icons.show_chart_rounded,
            title: 'Nothing to chart yet',
            message: 'Log a workout and records appear here automatically.',
          ),
          const SizedBox(height: 18),
          Text(
            'Progress is being wired up.',
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
