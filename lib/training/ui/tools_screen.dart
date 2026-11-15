import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import 'calculator_screens.dart';
import 'exercise_library_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = [
      _Tool(
        index: '01',
        title: 'Plate calculator',
        detail: 'Target weight to plates per side.',
        icon: Icons.donut_large_rounded,
        screen: const PlateCalculatorScreen(),
      ),
      _Tool(
        index: '02',
        title: 'Warm-up sets',
        detail: 'Percentages with a sensible ramp.',
        icon: Icons.bolt_rounded,
        screen: const WarmupCalculatorScreen(),
      ),
      _Tool(
        index: '03',
        title: '1RM table',
        detail: 'Estimate and training percentages.',
        icon: Icons.percent_rounded,
        screen: const OneRepMaxScreen(),
      ),
      _Tool(
        index: '04',
        title: 'Movements',
        detail: 'Search, filter and write your own.',
        icon: Icons.menu_book_rounded,
        screen: const ExerciseLibraryScreen(),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Text(
            'Calculators and the movement library.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: muted),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.98,
            children: [
              for (final tool in tools)
                Material(
                  color: panel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: hairline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => tool.screen),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(tool.icon, color: ember, size: 22),
                              const Spacer(),
                              Text(
                                tool.index,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: muted,
                                      letterSpacing: 1.4,
                                    ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            tool.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: cream),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tool.detail,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: muted, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const TrainingSectionTitle(title: 'Setup'),
          const SizedBox(height: 10),
          TrainingCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.settings_outlined, color: frost),
              title: const Text('Settings & backup'),
              subtitle: const Text(
                'Units, rest, plates, notifications, JSON and CSV.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: muted),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tool {
  const _Tool({
    required this.index,
    required this.title,
    required this.detail,
    required this.icon,
    required this.screen,
  });

  final String index;
  final String title;
  final String detail;
  final IconData icon;
  final Widget screen;
}
