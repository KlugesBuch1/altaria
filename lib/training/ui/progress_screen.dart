import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import '../calculators.dart';
import '../models.dart';
import '../training_scope.dart';
import 'charts.dart';
import 'exercise_progress_screen.dart';
import 'format.dart';
import 'widgets.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _busy = false;

  Future<void> _addMeasurement() async {
    final store = TrainingScope.of(context);
    final metric = await showModalBottomSheet<BodyMetric>(
      context: context,
      isScrollControlled: true,
      backgroundColor: panelHigh,
      showDragHandle: true,
      builder: (_) => _BodyMetricSheet(unit: store.settings.unit),
    );
    if (metric == null || !mounted) return;
    try {
      await store.addBodyMetric(metric);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Measurement saved.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _addPhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('The image could not be read.');
      }
      if (!mounted) return;
      await TrainingScope.of(context).addProgressPhoto(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress photo saved locally.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openPhoto(ProgressPhoto photo) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: panelHigh,
          contentPadding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  photo.bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Icon(Icons.broken_image_outlined, color: muted),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                formatDate(photo.takenAt),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: muted),
              ),
              if (photo.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(photo.note, textAlign: TextAlign.center),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final store = TrainingScope.of(context);
                Navigator.of(dialogContext).pop();
                await store.deleteProgressPhoto(photo.id);
              },
              child: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainingScope.of(context);
    final unit = store.settings.unit;
    final records = store.records.values.toList()
      ..sort((a, b) {
        final aDate =
            a.estimatedOneRepMax?.achievedAt ??
            a.maxWeight?.achievedAt ??
            DateTime(1970);
        final bDate =
            b.estimatedOneRepMax?.achievedAt ??
            b.maxWeight?.achievedAt ??
            DateTime(1970);
        return bDate.compareTo(aDate);
      });
    final metrics = [...store.bodyMetrics]
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    final weights = [
      for (final metric in metrics)
        if (metric.weightKg != null)
          ChartPoint(
            date: metric.measuredAt,
            value: convertFromKg(metric.weightKg!, unit),
          ),
    ];
    final latest = metrics.isEmpty ? null : metrics.last;
    final totalVolume = store.history.fold<double>(
      0,
      (total, workout) => total + workout.totalVolumeKg,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const TrainingHeader(
          eyebrow: 'Train',
          title: 'Progress',
          subtitle: 'Records, body data and photos. Stored on your device.',
        ),
        if (store.history.isNotEmpty) ...[
          const SizedBox(height: 18),
          TrainingCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: StatCell(
                    value: '${store.history.length}',
                    label: 'Sessions',
                    accent: frost,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: formatVolume(totalVolume, unit),
                    label: 'Lifetime volume',
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: '${records.length}',
                    label: 'Movements',
                    accent: ember,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        const TrainingSectionTitle(title: 'Personal records'),
        const SizedBox(height: 8),
        if (records.isEmpty)
          const EmptyPanel(
            icon: Icons.show_chart_rounded,
            title: 'Nothing to chart yet',
            message:
                'Finish a workout with completed sets and max weight, estimated '
                '1RM, volume and rep records appear here.',
          )
        else
          for (final record in records.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RecordCard(
                record: record,
                unit: unit,
                history: store.history,
              ),
            ),
        if (records.length > 6) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${records.length - 6} more movements have records. '
              'Open their workout history to review them.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: muted, height: 1.4),
            ),
          ),
        ],
        const SizedBox(height: 20),
        TrainingSectionTitle(
          title: 'Body',
          action: TextButton.icon(
            key: const Key('add-measurement'),
            onPressed: _addMeasurement,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Log'),
          ),
        ),
        const SizedBox(height: 8),
        if (latest == null)
          EmptyPanel(
            icon: Icons.monitor_weight_outlined,
            title: 'No body data yet',
            message:
                'Weight, body fat and tape measurements are optional. '
                'They stay local and export with your backup.',
            action: FilledButton.tonal(
              onPressed: _addMeasurement,
              child: const Text('Add a measurement'),
            ),
          )
        else
          TrainingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCell(
                        value: latest.weightKg == null
                            ? '—'
                            : '${weightValue(latest.weightKg!, unit)} ${unit.storage}',
                        label: 'Latest weight',
                        accent: ember,
                      ),
                    ),
                    Expanded(
                      child: StatCell(
                        value: latest.bodyFat == null
                            ? '—'
                            : '${_number(latest.bodyFat!)}%',
                        label: 'Body fat',
                        accent: frost,
                      ),
                    ),
                    Text(
                      formatDate(latest.measuredAt),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: muted),
                    ),
                  ],
                ),
                if (weights.length > 1) ...[
                  const SizedBox(height: 14),
                  TrainingLineChart(
                    points: weights,
                    unit: unit.storage,
                    color: ember,
                    height: 110,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    if (latest.waistCm != null)
                      _Measurement(label: 'Waist', value: latest.waistCm!),
                    if (latest.chestCm != null)
                      _Measurement(label: 'Chest', value: latest.chestCm!),
                    if (latest.hipsCm != null)
                      _Measurement(label: 'Hips', value: latest.hipsCm!),
                    if (latest.armCm != null)
                      _Measurement(label: 'Arm', value: latest.armCm!),
                    if (latest.thighCm != null)
                      _Measurement(label: 'Thigh', value: latest.thighCm!),
                  ],
                ),
                if (metrics.length > 1) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${metrics.length} measurements logged. '
                    'Latest: ${formatRelativeDay(latest.measuredAt)}.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: muted),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 20),
        TrainingSectionTitle(
          title: 'Progress photos',
          action: TextButton.icon(
            key: const Key('add-progress-photo'),
            onPressed: _busy ? null : _addPhoto,
            icon: const Icon(Icons.add_a_photo_outlined, size: 16),
            label: const Text('Add'),
          ),
        ),
        const SizedBox(height: 8),
        if (store.photos.isEmpty)
          TrainingCard(
            child: Row(
              children: [
                const Icon(Icons.photo_camera_back_outlined, color: muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Optional. Pick a photo from your device; it is copied into '
                    'the local backup and never uploaded.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: muted, height: 1.35),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: store.photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final photo = store.photos[index];
                return InkWell(
                  onTap: () => _openPhoto(photo),
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 112,
                      color: panel,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            photo.bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.broken_image_outlined,
                              color: muted,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              color: ink.withValues(alpha: 0.72),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 5,
                              ),
                              child: Text(
                                formatRelativeDay(photo.takenAt),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: cream, fontSize: 9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 22),
        Text(
          'No cloud sync and no purchase gates. Export everything from Settings.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: muted, height: 1.4),
        ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.unit,
    required this.history,
  });

  final ExerciseRecords record;
  final WeightUnit unit;
  final List<Workout> history;

  @override
  Widget build(BuildContext context) {
    final values = _topSetValues(history, record.exercise.id);
    return TrainingCard(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              ExerciseProgressScreen(exerciseId: record.exercise.id),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(15, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.exercise.name,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: cream, fontSize: 15),
                ),
              ),
              Text(
                '${record.workoutCount} ${record.workoutCount == 1 ? 'session' : 'sessions'}',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: muted, fontSize: 9),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, color: muted, size: 18),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _PrValue(
                  label: 'Heaviest',
                  value: record.maxWeight == null
                      ? '—'
                      : record.maxWeight!.weightKg > 0
                      ? formatWeight(record.maxWeight!.weightKg, unit)
                      : '${record.maxWeight!.reps} reps',
                ),
              ),
              Expanded(
                child: _PrValue(
                  label: 'Est. 1RM',
                  value: record.estimatedOneRepMax == null
                      ? '—'
                      : formatWeight(record.estimatedOneRepMax!.value, unit),
                  accent: frost,
                ),
              ),
              Expanded(
                child: _PrValue(
                  label: 'Set volume',
                  value: record.setVolume == null
                      ? '—'
                      : formatVolume(record.setVolume!.value, unit),
                ),
              ),
            ],
          ),
          if (record.repsAtWeight.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              'Rep PR: '
              '${record.repsAtWeight.take(2).map((entry) => '${entry.weightKg > 0 ? formatWeight(entry.weightKg, unit) : 'BW'} × ${entry.reps}').join('  ·  ')}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: muted),
            ),
          ],
          if (values.length > 1) ...[
            const SizedBox(height: 4),
            TrainingSparkline(values: values, color: ember),
          ],
        ],
      ),
    );
  }
}

class _PrValue extends StatelessWidget {
  const _PrValue({
    required this.label,
    required this.value,
    this.accent = cream,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: muted, fontSize: 8, letterSpacing: 0.8),
        ),
      ],
    );
  }
}

class _Measurement extends StatelessWidget {
  const _Measurement({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label ${_number(value)} cm',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
    );
  }
}

class _BodyMetricSheet extends StatefulWidget {
  const _BodyMetricSheet({required this.unit});

  final WeightUnit unit;

  @override
  State<_BodyMetricSheet> createState() => _BodyMetricSheetState();
}

class _BodyMetricSheetState extends State<_BodyMetricSheet> {
  late DateTime _date;
  final _weight = TextEditingController();
  final _fat = TextEditingController();
  final _chest = TextEditingController();
  final _waist = TextEditingController();
  final _hips = TextEditingController();
  final _arm = TextEditingController();
  final _thigh = TextEditingController();
  final _notes = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _weight.dispose();
    _fat.dispose();
    _chest.dispose();
    _waist.dispose();
    _hips.dispose();
    _arm.dispose();
    _thigh.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final weight = _parse(_weight.text);
    final fat = _parse(_fat.text);
    final chest = _parse(_chest.text);
    final waist = _parse(_waist.text);
    final hips = _parse(_hips.text);
    final arm = _parse(_arm.text);
    final thigh = _parse(_thigh.text);
    if (weight < 0 ||
        fat < 0 ||
        chest < 0 ||
        waist < 0 ||
        hips < 0 ||
        arm < 0 ||
        thigh < 0) {
      setState(() => _error = 'Measurements cannot be negative.');
      return;
    }
    if (weight == 0 &&
        fat == 0 &&
        chest == 0 &&
        waist == 0 &&
        hips == 0 &&
        arm == 0 &&
        thigh == 0) {
      setState(() => _error = 'Add at least one measurement.');
      return;
    }
    Navigator.of(context).pop(
      BodyMetric(
        id: 0,
        measuredAt: _date,
        weightKg: weight == 0 ? null : convertToKg(weight, widget.unit),
        bodyFat: fat == 0 ? null : fat,
        chestCm: chest == 0 ? null : chest,
        waistCm: waist == 0 ? null : waist,
        hipsCm: hips == 0 ? null : hips,
        armCm: arm == 0 ? null : arm,
        thighCm: thigh == 0 ? null : thigh,
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Log body data',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 15),
                      label: Text(formatDate(_date)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FieldLabel('Weight (${widget.unit.storage})'),
                          TextField(
                            key: const Key('body-weight'),
                            controller: _weight,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(hintText: '—'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('Body fat (%)'),
                          TextField(
                            key: const Key('body-fat'),
                            controller: _fat,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(hintText: '—'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _measure('Chest (cm)', _chest)),
                    const SizedBox(width: 10),
                    Expanded(child: _measure('Waist (cm)', _waist)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _measure('Hips (cm)', _hips)),
                    const SizedBox(width: 10),
                    Expanded(child: _measure('Arm (cm)', _arm)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _measure('Thigh (cm)', _thigh)),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Note (optional)',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('save-measurement'),
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save measurement'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _measure(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '—'),
        ),
      ],
    );
  }
}

List<double> _topSetValues(List<Workout> history, int exerciseId) {
  final workouts = [...history]
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final values = <double>[];
  for (final workout in workouts) {
    for (final exercise in workout.exercises) {
      if (exercise.exerciseId != exerciseId) continue;
      final sets = exercise.sets
          .where((set) => set.completed && !set.isWarmup)
          .toList();
      if (sets.isEmpty) break;
      values.add(sets.map((set) => set.weightKg).reduce(math.max));
      break;
    }
  }
  return values;
}

double _parse(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

String _number(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}
