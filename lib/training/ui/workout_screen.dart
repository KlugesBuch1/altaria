import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import 'widgets.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TrainingHeader(
            eyebrow: 'Train',
            title: 'Workout',
            subtitle: 'Log a session, or pick up a routine.',
          ),
          const SizedBox(height: 24),
          EmptyPanel(
            icon: Icons.fitness_center_rounded,
            title: 'The bar is loaded.',
            message: 'Start empty or bring a routine. Nothing is locked.',
            action: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_rounded),
              label: const Text('Start empty workout'),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Workout tools are being wired up.',
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
