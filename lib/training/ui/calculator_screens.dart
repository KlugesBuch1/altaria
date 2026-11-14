import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import '../calculators.dart';
import '../training_scope.dart';
import 'settings_screen.dart';
import 'widgets.dart';

class PlateCalculatorScreen extends StatefulWidget {
  const PlateCalculatorScreen({super.key});

  @override
  State<PlateCalculatorScreen> createState() => _PlateCalculatorScreenState();
}

class _PlateCalculatorScreenState extends State<PlateCalculatorScreen> {
  final _target = TextEditingController();

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = TrainingScope.of(context).settings;
    final unit = settings.unit;
    final target = _parse(_target.text);
    PlateSolution? solution;
    if (target > 0) {
      solution = calculatePlates(
        targetWeightKg: target,
        barWeightKg: settings.barWeight,
        availablePlatesKg: settings.plateInventory,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Plate calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Text(
            'Load the bar without counting on your fingers.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: muted),
          ),
          const SizedBox(height: 20),
          FieldLabel('Target weight (${unit.storage})'),
          TextField(
            key: const Key('plate-target'),
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '100',
              prefixIcon: Icon(Icons.scale_outlined, color: frost),
            ),
          ),
          const SizedBox(height: 18),
          if (solution == null)
            EmptyPanel(
              icon: Icons.fitness_center_rounded,
              title: 'Bar and plates, solved',
              message:
                  'Enter a target. The calculator uses your saved bar and '
                  'plate pairs in ${unit.storage}.',
              action: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Bar & plate setup'),
              ),
            )
          else if (!solution.canLoad)
            EmptyPanel(
              icon: Icons.warning_amber_rounded,
              title: 'Below bar weight',
              message:
                  'The empty bar is ${_number(settings.barWeight)} '
                  '${unit.storage}. Choose a heavier target.',
            )
          else ...[
            TrainingCard(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TrainingTag(
                        label: solution.exact ? 'Exact' : 'Closest',
                        color: solution.exact ? frost : ember,
                      ),
                      const Spacer(),
                      Text(
                        '${_number(settings.barWeight)} ${unit.storage} bar',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'PER SIDE',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: muted, letterSpacing: 1.4),
                  ),
                  const SizedBox(height: 8),
                  if (solution.platesKg.isEmpty)
                    Text(
                      'No plates',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: muted),
                    )
                  else
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final plate in solution.platesKg)
                          _PlateDisc(label: _number(plate)),
                      ],
                    ),
                  const SizedBox(height: 18),
                  SectionDivider(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: StatCell(
                          value:
                              '${_number(solution.perSideKg)} ${unit.storage}',
                          label: 'Per side',
                          accent: ember,
                        ),
                      ),
                      Expanded(
                        child: StatCell(
                          value:
                              '${_number(solution.achievedWeightKg)} ${unit.storage}',
                          label: 'Loaded',
                        ),
                      ),
                      Expanded(
                        child: StatCell(
                          value: solution.exact
                              ? '0'
                              : _number(solution.remainderKg),
                          label: solution.exact ? 'Gap' : 'Gap ${unit.storage}',
                          accent: solution.exact ? frost : rose,
                        ),
                      ),
                    ],
                  ),
                  if (!solution.exact) ...[
                    const SizedBox(height: 12),
                    Text(
                      'The closest load with this rack is '
                      '${_number(solution.achievedWeightKg)} ${unit.storage}.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Bar & plate setup'),
            ),
          ],
        ],
      ),
    );
  }
}

class WarmupCalculatorScreen extends StatefulWidget {
  const WarmupCalculatorScreen({super.key});

  @override
  State<WarmupCalculatorScreen> createState() => _WarmupCalculatorScreenState();
}

class _WarmupCalculatorScreenState extends State<WarmupCalculatorScreen> {
  final _working = TextEditingController();

  @override
  void dispose() {
    _working.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = TrainingScope.of(context).settings.unit;
    final working = _parse(_working.text);
    final sets = warmupSets(working);
    return Scaffold(
      appBar: AppBar(title: const Text('Warm-up sets')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Text(
            'Build up to the working weight without guessing the jumps.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: muted),
          ),
          const SizedBox(height: 20),
          FieldLabel('Working weight (${unit.storage})'),
          TextField(
            key: const Key('warmup-weight'),
            controller: _working,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '100',
              prefixIcon: Icon(Icons.bolt_rounded, color: ember),
            ),
          ),
          const SizedBox(height: 18),
          if (sets.isEmpty)
            const EmptyPanel(
              icon: Icons.bolt_outlined,
              title: 'Four steps up',
              message:
                  'Enter the top set weight. Warm-ups use 40, 60, 80 and 90 '
                  'percent with decreasing reps.',
            )
          else
            TrainingCard(
              child: Column(
                children: [
                  for (var index = 0; index < sets.length; index++) ...[
                    Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${sets[index].percent}%',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: frost),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${_number(sets[index].weightKg)} ${unit.storage}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: cream,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                        Text(
                          '${sets[index].reps} reps',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: muted),
                        ),
                      ],
                    ),
                    if (index < sets.length - 1) ...[
                      const SizedBox(height: 8),
                      SectionDivider(),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Percentages are of the working weight, not a tested max.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class OneRepMaxScreen extends StatefulWidget {
  const OneRepMaxScreen({super.key});

  @override
  State<OneRepMaxScreen> createState() => _OneRepMaxScreenState();
}

class _OneRepMaxScreenState extends State<OneRepMaxScreen> {
  final _weight = TextEditingController();
  final _reps = TextEditingController();

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = TrainingScope.of(context).settings.unit;
    final weight = _parse(_weight.text);
    final reps = int.tryParse(_reps.text.trim()) ?? 0;
    final estimate = estimateOneRepMax(weight, reps);
    final table = oneRepMaxTable(estimate);
    return Scaffold(
      appBar: AppBar(title: const Text('1RM & percentages')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Text(
            'An Epley estimate from a set you already did.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: muted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel('Weight (${unit.storage})'),
                    TextField(
                      key: const Key('one-rep-weight'),
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(hintText: '100'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Reps'),
                    TextField(
                      key: const Key('one-rep-reps'),
                      controller: _reps,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(hintText: '5'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (estimate <= 0)
            const EmptyPanel(
              icon: Icons.percent_rounded,
              title: 'Find the ceiling',
              message:
                  'Enter a weight and reps from a working set. A single rep '
                  'returns the weight itself.',
            )
          else ...[
            TrainingCard(
              color: panelHigh,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ESTIMATED 1RM',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: ember, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_number(estimate)} ${unit.storage}',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(color: cream),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'From ${_number(weight)} ${unit.storage} × $reps',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.trending_up_rounded, color: ember, size: 30),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const TrainingSectionTitle(title: 'Training percentages'),
            const SizedBox(height: 10),
            TrainingCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var index = 0; index < table.length; index++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 58,
                            child: Text(
                              '${table[index].percent}%',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: frost),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _number(table[index].weightKg),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: cream,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ),
                          Text(
                            unit.storage,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ),
                    if (index < table.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'The estimate is a guide, not a tested single. Don’t chase it '
            'with sloppy reps.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _PlateDisc extends StatelessWidget {
  const _PlateDisc({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: panelHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ember.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: cream,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

double _parse(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

String _number(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
