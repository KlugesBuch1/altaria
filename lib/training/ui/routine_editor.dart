import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import '../calculators.dart';
import '../models.dart';
import '../repository.dart';
import '../training_scope.dart';
import 'exercise_library_screen.dart';
import 'format.dart';
import 'widgets.dart';

class RoutineEditorScreen extends StatefulWidget {
  const RoutineEditorScreen({super.key, this.routine});

  final Routine? routine;

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late List<RoutineExercise> _exercises;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final routine = widget.routine;
    _name = TextEditingController(text: routine?.name ?? '');
    _notes = TextEditingController(text: routine?.notes ?? '');
    _exercises = [...?routine?.exercises];
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addExercise() async {
    final store = TrainingScope.of(context);
    final picked = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => const ExerciseLibraryScreen(picker: true),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _exercises = [
        ..._exercises,
        RoutineExercise(
          id: 0,
          exercise: picked,
          position: _exercises.length,
          targetSets: 3,
          targetReps: 8,
          restSeconds: store.settings.defaultRestSeconds,
        ),
      ];
    });
  }

  Future<void> _configure(int index) async {
    final store = TrainingScope.of(context);
    final updated = await showRoutineExerciseEditor(
      context,
      exercise: _exercises[index],
      unit: store.settings.unit,
    );
    if (updated == null || !mounted) return;
    setState(() {
      _exercises = [..._exercises]..[index] = updated;
    });
  }

  void _move(int index, int direction) {
    final target = index + direction;
    if (target < 0 || target >= _exercises.length) return;
    setState(() {
      final items = [..._exercises];
      final item = items.removeAt(index);
      items.insert(target, item);
      _exercises = items;
    });
  }

  void _remove(int index) {
    setState(() {
      _exercises = [..._exercises]..removeAt(index);
    });
  }

  Future<void> _save() async {
    final store = TrainingScope.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Give the routine a name.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await store.saveRoutine(
        id: widget.routine?.id,
        name: name,
        notes: _notes.text,
        exercises: [
          for (var index = 0; index < _exercises.length; index++)
            _exercises[index].copyWith(position: index),
        ],
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on TrainingRepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the routine.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.routine != null;
    final unit = TrainingScope.of(context).settings.unit;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit routine' : 'New routine'),
        actions: [
          TextButton(
            key: const Key('save-routine-top'),
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const FieldLabel('Name'),
          TextField(
            key: const Key('routine-name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            autofocus: !editing,
            decoration: const InputDecoration(hintText: 'Push A'),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Routine note'),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Optional. Setup, intent, a reminder.',
            ),
          ),
          const SizedBox(height: 22),
          TrainingSectionTitle(
            title: 'Exercises (${_exercises.length})',
            action: TextButton.icon(
              key: const Key('add-routine-exercise'),
              onPressed: _addExercise,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Add'),
            ),
          ),
          const SizedBox(height: 6),
          if (_exercises.isEmpty)
            EmptyPanel(
              icon: Icons.playlist_add_rounded,
              title: 'No movements yet',
              message: 'Add movements now or save the routine empty and build it later.',
              action: FilledButton.tonalIcon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add movement'),
              ),
            )
          else
            for (var index = 0; index < _exercises.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RoutineExerciseCard(
                  key: Key('routine-exercise-$index'),
                  exercise: _exercises[index],
                  unit: unit,
                  canMoveUp: index > 0,
                  canMoveDown: index < _exercises.length - 1,
                  onTap: () => _configure(index),
                  onAction: (action) {
                    if (action == 'up') _move(index, -1);
                    if (action == 'down') _move(index, 1);
                    if (action == 'remove') _remove(index);
                    if (action == 'edit') _configure(index);
                  },
                ),
              ),
          if (_exercises.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _addExercise,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add movement'),
            ),
          const SizedBox(height: 28),
          Text(
            'Tap a movement to set targets, rest and superset group. '
            'Routine changes stay on this device.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted, height: 1.4),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('save-routine'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(editing ? 'Save changes' : 'Create routine'),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutineExerciseCard extends StatelessWidget {
  const _RoutineExerciseCard({
    super.key,
    required this.exercise,
    required this.unit,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onTap,
    required this.onAction,
  });

  final RoutineExercise exercise;
  final WeightUnit unit;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final weight = exercise.targetWeightKg;
    return TrainingCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: hairline),
            ),
            child: Text(
              '${exercise.position + 1}',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: muted),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.exercise.name,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: cream, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${exercise.targetSets} × ${exercise.targetReps}'
                      '${weight != null ? ' @ ${formatWeight(weight, unit)}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: ember),
                    ),
                    Text(
                      '${formatRest(exercise.restSeconds)} rest',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: muted),
                    ),
                    if (exercise.supersetGroup > 0)
                      TrainingTag(
                        label: 'Superset ${_letter(exercise.supersetGroup)}',
                        color: frost,
                      ),
                  ],
                ),
                if (exercise.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exercise.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: muted),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Movement options',
            color: panelHigh,
            icon: const Icon(Icons.more_vert_rounded, color: muted),
            onSelected: onAction,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit targets')),
              PopupMenuItem(
                value: 'up',
                enabled: canMoveUp,
                child: const Text('Move up'),
              ),
              PopupMenuItem(
                value: 'down',
                enabled: canMoveDown,
                child: const Text('Move down'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }
}

Future<RoutineExercise?> showRoutineExerciseEditor(
  BuildContext context, {
  required RoutineExercise exercise,
  required WeightUnit unit,
}) {
  return showModalBottomSheet<RoutineExercise>(
    context: context,
    isScrollControlled: true,
    backgroundColor: panelHigh,
    showDragHandle: true,
    builder: (context) {
      return _RoutineExerciseEditor(exercise: exercise, unit: unit);
    },
  );
}

class _RoutineExerciseEditor extends StatefulWidget {
  const _RoutineExerciseEditor({required this.exercise, required this.unit});

  final RoutineExercise exercise;
  final WeightUnit unit;

  @override
  State<_RoutineExerciseEditor> createState() => _RoutineExerciseEditorState();
}

class _RoutineExerciseEditorState extends State<_RoutineExerciseEditor> {
  late final TextEditingController _sets;
  late final TextEditingController _reps;
  late final TextEditingController _weight;
  late final TextEditingController _rest;
  late final TextEditingController _notes;
  late int _superset;
  String? _error;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    _sets = TextEditingController(text: '${exercise.targetSets}');
    _reps = TextEditingController(text: '${exercise.targetReps}');
    _weight = TextEditingController(
      text: exercise.targetWeightKg == null
          ? ''
          : weightValue(exercise.targetWeightKg!, widget.unit),
    );
    _rest = TextEditingController(text: '${exercise.restSeconds}');
    _notes = TextEditingController(text: exercise.notes);
    _superset = exercise.supersetGroup;
  }

  @override
  void dispose() {
    _sets.dispose();
    _reps.dispose();
    _weight.dispose();
    _rest.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final sets = int.tryParse(_sets.text.trim()) ?? 0;
    final reps = int.tryParse(_reps.text.trim()) ?? 0;
    final rest = int.tryParse(_rest.text.trim()) ?? 0;
    final weightText = _weight.text.trim();
    final weight = weightText.isEmpty
        ? null
        : double.tryParse(weightText.replaceAll(',', '.'));
    if (sets < 1 || reps < 1 || rest < 0 || rest > 900) {
      setState(() => _error = 'Sets and reps need to be at least 1.');
      return;
    }
    if (weight != null && weight < 0) {
      setState(() => _error = 'Check the weight.');
      return;
    }
    Navigator.of(context).pop(
      widget.exercise.copyWith(
        targetSets: sets,
        targetReps: reps,
        targetWeightKg: weight == null
            ? null
            : convertToKg(weight, widget.unit),
        restSeconds: rest,
        supersetGroup: _superset,
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
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Targets', style: theme.textTheme.titleLarge),
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
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('Sets'),
                          TextField(
                            key: const Key('target-sets'),
                            controller: _sets,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '3'),
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
                            key: const Key('target-reps'),
                            controller: _reps,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '8'),
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
                          FieldLabel('Weight (${widget.unit.storage})'),
                          TextField(
                            key: const Key('target-weight'),
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
                          const FieldLabel('Rest (sec)'),
                          TextField(
                            key: const Key('target-rest'),
                            controller: _rest,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '90'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const FieldLabel('Superset group'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var group = 0; group <= 3; group++)
                      ChoiceChip(
                        label: Text(group == 0 ? 'None' : _letter(group)),
                        selected: _superset == group,
                        showCheckmark: false,
                        backgroundColor: panel,
                        selectedColor: wine,
                        side: BorderSide(
                          color: _superset == group ? ember : hairline,
                        ),
                        onSelected: (_) => setState(() => _superset = group),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const FieldLabel('Note'),
                TextField(
                  key: const Key('target-notes'),
                  controller: _notes,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Tempo, setup, a cue.',
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
                    key: const Key('save-targets'),
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save targets'),
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

String _letter(int group) {
  const letters = ['A', 'B', 'C', 'D'];
  return group >= 1 && group <= letters.length ? letters[group - 1] : '$group';
}
