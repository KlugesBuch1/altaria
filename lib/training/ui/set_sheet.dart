import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import '../calculators.dart';
import '../models.dart';
import 'widgets.dart';

Future<WorkoutSet?> showSetEditorSheet(
  BuildContext context, {
  required WorkoutExercise exercise,
  required WeightUnit unit,
  required Future<void> Function(WorkoutSet) onSave,
  WorkoutSet? existing,
  WorkoutSet? previous,
}) {
  return showModalBottomSheet<WorkoutSet>(
    context: context,
    isScrollControlled: true,
    backgroundColor: panelHigh,
    showDragHandle: true,
    builder: (context) {
      return _SetEditorSheet(
        exercise: exercise,
        unit: unit,
        existing: existing,
        previous: previous,
        onSave: onSave,
      );
    },
  );
}

class _SetEditorSheet extends StatefulWidget {
  const _SetEditorSheet({
    required this.exercise,
    required this.unit,
    required this.onSave,
    this.existing,
    this.previous,
  });

  final WorkoutExercise exercise;
  final WeightUnit unit;
  final Future<void> Function(WorkoutSet) onSave;
  final WorkoutSet? existing;
  final WorkoutSet? previous;

  @override
  State<_SetEditorSheet> createState() => _SetEditorSheetState();
}

class _SetEditorSheetState extends State<_SetEditorSheet> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;
  late final TextEditingController _duration;
  late final TextEditingController _distance;
  late final TextEditingController _rpe;
  late final TextEditingController _notes;
  late SetKind _kind;
  late bool _completed;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final previous = widget.previous;
    final source = existing ?? previous;
    final weight =
        existing?.weightKg ??
        (widget.exercise.targetWeightKg != null &&
                widget.exercise.targetWeightKg! > 0
            ? widget.exercise.targetWeightKg!
            : source?.weightKg ?? 0);
    final reps =
        existing?.reps ??
        (widget.exercise.targetReps > 0
            ? widget.exercise.targetReps
            : source?.reps ?? 0);
    _weight = TextEditingController(
      text: weight > 0 ? weightValue(weight, widget.unit) : '',
    );
    _reps = TextEditingController(text: reps > 0 ? '$reps' : '');
    _duration = TextEditingController(
      text: (source?.durationSeconds ?? 0) > 0
          ? '${source!.durationSeconds}'
          : '',
    );
    _distance = TextEditingController(
      text: (source?.distanceMeters ?? 0) > 0
          ? source!.distanceMeters.toStringAsFixed(0)
          : '',
    );
    _rpe = TextEditingController(
      text: source?.rpe == null
          ? ''
          : source!.rpe!.toStringAsFixed(source.rpe! % 1 == 0 ? 0 : 1),
    );
    _notes = TextEditingController(text: existing?.notes ?? '');
    _kind = existing?.kind ?? SetKind.normal;
    _completed = existing?.completed ?? true;
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _duration.dispose();
    _distance.dispose();
    _rpe.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final weight = _parseDouble(_weight.text);
    final reps = _parseInt(_reps.text);
    final duration = _parseInt(_duration.text);
    final distance = _parseDouble(_distance.text);
    final rpe = _rpe.text.trim().isEmpty ? null : _parseDouble(_rpe.text);
    if (weight < 0 ||
        reps < 0 ||
        duration < 0 ||
        distance < 0 ||
        (rpe != null && (rpe < 1 || rpe > 10))) {
      setState(() => _error = 'Check the numbers and try again.');
      return;
    }
    if (reps == 0 && duration == 0 && distance == 0) {
      setState(() => _error = 'Add reps, time or distance.');
      return;
    }
    final base = widget.existing;
    final result = base == null
        ? WorkoutSet(
            id: 0,
            position: 0,
            kind: _kind,
            weightKg: convertToKg(weight, widget.unit),
            reps: reps,
            durationSeconds: duration,
            distanceMeters: distance,
            rpe: rpe,
            completed: _completed,
            notes: _notes.text.trim(),
          )
        : base.copyWith(
            kind: _kind,
            weightKg: convertToKg(weight, widget.unit),
            reps: reps,
            durationSeconds: duration,
            distanceMeters: distance,
            rpe: rpe,
            completed: _completed,
            notes: _notes.text.trim(),
          );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(result);
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyweight =
        widget.exercise.exercise.equipment == Equipment.bodyweight;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existing == null ? 'Log set' : 'Edit set',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.exercise.exercise.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const FieldLabel('Set type'),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final kind in SetKind.values)
                      ChoiceChip(
                        label: Text(kind.label),
                        selected: _kind == kind,
                        onSelected: (_) => setState(() => _kind = kind),
                        showCheckmark: false,
                        backgroundColor: panel,
                        selectedColor: kind == SetKind.failure
                            ? const Color(0xFF6C1B18)
                            : wine,
                        side: BorderSide(
                          color: _kind == kind ? ember : hairline,
                        ),
                        labelStyle: theme.textTheme.bodySmall?.copyWith(
                          color: cream,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FieldLabel(
                            bodyweight
                                ? 'Added weight (${widget.unit.storage})'
                                : 'Weight (${widget.unit.storage})',
                          ),
                          TextField(
                            key: const Key('set-weight'),
                            controller: _weight,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: bodyweight ? 'BW' : '0',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('Reps'),
                          TextField(
                            key: const Key('set-reps'),
                            controller: _reps,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '0'),
                          ),
                        ],
                      ),
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
                          const FieldLabel('Time (sec)'),
                          TextField(
                            key: const Key('set-duration'),
                            controller: _duration,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '0'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('Distance (m)'),
                          TextField(
                            key: const Key('set-distance'),
                            controller: _distance,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(hintText: '0'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('RPE'),
                          TextField(
                            key: const Key('set-rpe'),
                            controller: _rpe,
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
                const SizedBox(height: 14),
                TextField(
                  key: const Key('set-notes'),
                  controller: _notes,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Set note (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const Key('set-completed'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Completed',
                    style: theme.textTheme.bodyMedium?.copyWith(color: cream),
                  ),
                  subtitle: Text(
                    'Rest starts when a set is completed.',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  value: _completed,
                  activeThumbColor: ember,
                  activeTrackColor: wine,
                  onChanged: (value) => setState(() => _completed = value),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('save-set'),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Save set'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

double _parseDouble(String value) {
  return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
}

int _parseInt(String value) =>
    int.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
