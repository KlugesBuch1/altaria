import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import 'widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TrainingHeader(
            eyebrow: 'Train',
            title: 'History',
            subtitle: 'Every session stays on this device.',
          ),
          const SizedBox(height: 24),
          const EmptyPanel(
            icon: Icons.history_rounded,
            title: 'No sessions logged',
            message: 'Finish a workout and it lands here with volume and time.',
          ),
          const SizedBox(height: 18),
          Text(
            'History is being wired up.',
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
