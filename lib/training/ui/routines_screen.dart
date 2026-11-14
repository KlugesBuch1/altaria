import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import 'widgets.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TrainingHeader(
            eyebrow: 'Train',
            title: 'Routines',
            subtitle: 'Write the session once. Start it whenever.',
          ),
          const SizedBox(height: 24),
          const EmptyPanel(
            icon: Icons.view_agenda_outlined,
            title: 'No routines yet',
            message:
                'A routine keeps exercise order, targets and rest together.',
          ),
          const SizedBox(height: 18),
          Text(
            'Routine editing is being wired up.',
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
