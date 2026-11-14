import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../theme.dart';
import '../calculators.dart';
import '../models.dart';
import '../rest_timer.dart';
import '../training_scope.dart';
import '../training_store.dart';
import 'exercise_library_screen.dart';
import 'format.dart';
import 'set_sheet.dart';
import 'widgets.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  RestTimerController? _rest;
  final Map<int, PreviousPerformance?> _previous = {};
  bool _initialized = false;
  bool _finishing = false;
  bool _addingExercise = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final store = TrainingScope.of(context);
    _rest = RestTimerController(
      notifier: store.notifier,
      notificationsEnabled: store.settings.restNotifications,
      onFinished: () =>
          unawaited(HapticFeedback.mediumImpact().catchError((_) {})),
    );
    unawaited(_loadPrevious());
    if (store.settings.keepAwake) {
      unawaited(_setKeepAwake(true));
    }
    if (store.settings.restNotifications) {
      unawaited(store.ensureRestNotificationPermission());
    }
  }

  @override
  void dispose() {
    _rest?.dispose();
    unawaited(_setKeepAwake(false));
    super.dispose();
  }

  Future<void> _setKeepAwake(bool enabled) async {
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // The screen stays usable when the platform cannot hold a wake lock.
    }
  }

  Future<void> _loadPrevious() async {
    if (!mounted) return;
    final store = TrainingScope.of(context);
    final workout = store.activeWorkout;
    if (workout == null) return;
    final loaded = <int, PreviousPerformance?>{};
    for (final exercise in workout.exercises) {
      loaded[exercise.exerciseId] = await store.previousPerformance(
        exercise.exerciseId,
      );
    }
    if (!mounted) return;
    setState(() => _previous.addAll(loaded));
  }

  Future<void> _loadPreviousFor(Exercise exercise) async {
    final store = TrainingScope.of(context);
    final previous = await store.previousPerformance(exercise.id);
    if (!mounted) return;
    setState(() => _previous[exercise.id] = previous);
  }

  Future<void> _addExercise() async {
    if (_addingExercise) return;
    setState(() => _addingExercise = true);
    final picked = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => const ExerciseLibraryScreen(picker: true),
      ),
    );
    if (!mounted) return;
    setState(() => _addingExercise = false);
    if (picked == null) return;
    final store = TrainingScope.of(context);
    try {
      await store.addExercise(picked);
      await _loadPreviousFor(picked);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _openSet(
    WorkoutExercise exercise, {
    WorkoutSet? existing,
  }) async {
    final store = TrainingScope.of(context);
    final previous = existing == null
        ? _lastSetInWorkout(exercise) ?? _lastPreviousSet(exercise.exerciseId)
        : null;
    final result = await showSetEditorSheet(
      context,
      exercise: exercise,
      unit: store.settings.unit,
      existing: existing,
      previous: previous,
      onSave: (saved) async {
        if (existing == null) {
          await store.addSet(exercise.id, saved);
        } else {
          await store.updateSet(saved);
        }
      },
    );
    if (result == null || !mounted) return;
    if (result.completed && !(existing?.completed ?? false)) {
      await _afterCompletedSet(exercise);
    }
  }

  WorkoutSet? _lastSetInWorkout(WorkoutExercise exercise) {
    if (exercise.sets.isEmpty) return null;
    for (final set in exercise.sets.reversed) {
      if (set.completed) return set;
    }
    return exercise.sets.last;
  }

  WorkoutSet? _lastPreviousSet(int exerciseId) {
    final previous = _previous[exerciseId];
    if (previous == null || previous.sets.isEmpty) return null;
    for (final set in previous.sets.reversed) {
      if (set.completed) return set;
    }
    return previous.sets.last;
  }

  Future<void> _toggleSet(WorkoutExercise exercise, WorkoutSet set) async {
    final store = TrainingScope.of(context);
    final next = set.copyWith(completed: !set.completed);
    try {
      await store.updateSet(next);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
      return;
    }
    if (next.completed && mounted) {
      await _afterCompletedSet(exercise);
    }
  }

  Future<void> _afterCompletedSet(WorkoutExercise completed) async {
    final store = TrainingScope.of(context);
    final workout = store.activeWorkout;
    if (workout == null) return;
    final current = workout.exercises.firstWhere(
      (exercise) => exercise.id == completed.id,
      orElse: () => completed,
    );
    final seconds = current.restSeconds > 0
        ? current.restSeconds
        : store.settings.defaultRestSeconds;
    if (seconds > 0) {
      _rest?.start(seconds);
    }
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {
      // Haptics are optional.
    }
    final next = _nextInSuperset(workout, current);
    if (next != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Superset ${_supersetLabel(current.supersetGroup)}: '
              'next is ${next.exercise.name}',
            ),
            action: SnackBarAction(
              label: 'Log set',
              onPressed: () => unawaited(_openSet(next)),
            ),
          ),
        );
    }
  }

  WorkoutExercise? _nextInSuperset(Workout workout, WorkoutExercise current) {
    if (current.supersetGroup <= 0) return null;
    final group = workout.exercises
        .where((exercise) => exercise.supersetGroup == current.supersetGroup)
        .toList(growable: false);
    if (group.length < 2) return null;
    final index = group.indexWhere((exercise) => exercise.id == current.id);
    if (index < 0) return null;
    return group[(index + 1) % group.length];
  }

  Future<void> _exerciseAction(
    WorkoutExercise exercise,
    String action,
    Workout workout,
  ) async {
    switch (action) {
      case 'rest':
        await _editRest(exercise);
      case 'superset':
        await _editSuperset(exercise);
      case 'notes':
        await _editNotes(exercise);
      case 'up':
        await _move(exercise, workout, -1);
      case 'down':
        await _move(exercise, workout, 1);
      case 'remove':
        await _remove(exercise);
    }
  }

  Future<void> _editRest(WorkoutExercise exercise) async {
    final controller = TextEditingController(text: '${exercise.restSeconds}');
    final seconds = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panelHigh,
        title: const Text('Rest between sets'),
        content: TextField(
          key: const Key('rest-seconds'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            suffixText: 'seconds',
            hintText: '90',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 0 || value > 900) return;
              Navigator.of(context).pop(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (seconds == null || !mounted) return;
    await TrainingScope.of(context)
        .updateWorkoutExercise(exercise, restSeconds: seconds);
  }

  Future<void> _editSuperset(WorkoutExercise exercise) async {
    var selected = exercise.supersetGroup;
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              backgroundColor: panelHigh,
              title: const Text('Superset group'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Give paired or grouped movements the same letter. '
                    'After a set, altaria offers the next movement.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: muted, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var group = 0; group <= 3; group++)
                        ChoiceChip(
                          label: Text(
                            group == 0 ? 'None' : _supersetLabel(group),
                          ),
                          selected: selected == group,
                          showCheckmark: false,
                          backgroundColor: panel,
                          selectedColor: wine,
                          side: BorderSide(
                            color: selected == group ? ember : hairline,
                          ),
                          onSelected: (_) => setLocal(() => selected = group),
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    await TrainingScope.of(context)
        .updateWorkoutExercise(exercise, supersetGroup: result);
  }

  Future<void> _editNotes(WorkoutExercise exercise) async {
    final controller = TextEditingController(text: exercise.notes);
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panelHigh,
        title: const Text('Exercise note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Setup, tempo, a cue for next time.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (notes == null || !mounted) return;
    await TrainingScope.of(context)
        .updateWorkoutExercise(exercise, notes: notes);
  }

  Future<void> _move(
    WorkoutExercise exercise,
    Workout workout,
    int direction,
  ) async {
    final ordered = [...workout.exercises]
      ..sort((a, b) => a.position.compareTo(b.position));
    final index = ordered.indexWhere((item) => item.id == exercise.id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= ordered.length) return;
    final moved = ordered.removeAt(index);
    ordered.insert(target, moved);
    await TrainingScope.of(context).reorderExercises(
      workout.id,
      ordered.map((item) => item.id).toList(growable: false),
    );
  }

  Future<void> _remove(WorkoutExercise exercise) async {
    final confirmed = await confirmAction(
      context,
      title: 'Remove ${exercise.exercise.name}?',
      message: exercise.sets.isEmpty ? 'It leaves this workout only.' : 'Its logged sets leave this workout. The movement stays in the library.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await TrainingScope.of(context).removeExercise(exercise.id);
  }

  Future<void> _finish() async {
    final store = TrainingScope.of(context);
    final workout = store.activeWorkout;
    if (workout == null || _finishing) return;
    if (workout.completedSetCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete at least one set first.')),
      );
      return;
    }
    final seconds = DateTime.now().difference(workout.startedAt).inSeconds;
    final confirmed = await confirmAction(
      context,
      title: 'Finish workout?',
      message:
          '${workout.completedSetCount} sets · '
          '${formatVolume(workoutVolumeKg(workout), store.settings.unit)} · '
          '${formatTrainingDuration(seconds)}',
      confirmLabel: 'Finish',
    );
    if (!confirmed || !mounted) return;
    setState(() => _finishing = true);
    _rest?.skip();
    try {
      final result = await store.finishActiveWorkout();
      if (!mounted) return;
      await _showSaved(result);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _showSaved(WorkoutFinishResult result) async {
    final store = TrainingScope.of(context);
    final unit = store.settings.unit;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          key: const Key('workout-saved'),
          backgroundColor: panelHigh,
          title: const Text('Session saved'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCell(
                        value: '${result.workout.setCount}',
                        label: 'Sets',
                        accent: ember,
                      ),
                    ),
                    Expanded(
                      child: StatCell(
                        value: formatVolume(result.workout.totalVolumeKg, unit),
                        label: 'Volume',
                      ),
                    ),
                    Expanded(
                      child: StatCell(
                        value: formatTrainingDuration(
                          result.workout.durationSeconds,
                        ),
                        label: 'Time',
                        accent: frost,
                      ),
                    ),
                  ],
                ),
                if (result.newRecords.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    'NEW RECORDS',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: ember, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  for (final update in result.newRecords)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text(
                        '${update.exercise.name} — ${update.label}: '
                        '${update.label == 'Set volume' ? formatVolume(update.value, unit) : formatWeight(update.value, unit)}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: cream),
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _discard() async {
    final confirmed = await confirmAction(
      context,
      title: 'Discard this workout?',
      message: 'Its sets, time and notes are deleted.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final store = TrainingScope.of(context);
    await store.discardActiveWorkout();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainingScope.of(context);
    final workout = store.activeWorkout;
    if (workout == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('No active workout.', style: TextStyle(color: muted)),
        ),
      );
    }
    final unit = store.settings.unit;
    final elapsed = DateTime.now().difference(workout.startedAt).inSeconds;
    final groups = _groupExercises(workout);
    final rest = _rest;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to workout tab',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workout.name,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: cream, fontSize: 16),
            ),
            Text(
              'Started ${TimeOfDay.fromDateTime(workout.startedAt.toLocal()).format(context)}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add movement',
            onPressed: _addingExercise ? null : _addExercise,
            icon: const Icon(Icons.add_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Workout menu',
            color: panelHigh,
            onSelected: (value) {
              if (value == 'finish') unawaited(_finish());
              if (value == 'discard') unawaited(_discard());
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'finish', child: Text('Finish workout')),
              PopupMenuItem(value: 'discard', child: Text('Discard workout')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          TrainingCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: StatCell(
                    value: formatTrainingDuration(elapsed),
                    label: 'Elapsed',
                    accent: frost,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: '${workout.completedSetCount}',
                    label: 'Done',
                    accent: ember,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: formatVolume(workoutVolumeKg(workout), unit),
                    label: 'Volume',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (groups.isEmpty)
            EmptyPanel(
              icon: Icons.add_circle_outline_rounded,
              title: 'Add the first movement',
              message:
                  'The workout is empty until you choose something. '
                  'Targets are optional.',
              action: FilledButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Choose movement'),
              ),
            )
          else
            for (final group in groups)
              _buildGroup(group, store, workout, unit),
          if (groups.isNotEmpty) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _addingExercise ? null : _addExercise,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add movement'),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rest != null)
              _RestPanel(controller: rest)
            else
              const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('finish-workout'),
                  onPressed: _finishing ? null : _finish,
                  icon: _finishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Finish workout'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(
    _ExerciseGroup group,
    TrainingStore store,
    Workout workout,
    WeightUnit unit,
  ) {
    final first = group.exercises.first;
    final isSuperset = first.supersetGroup > 0 && group.exercises.length > 1;
    final ordered = [...workout.exercises]
      ..sort((a, b) => a.position.compareTo(b.position));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSuperset) ...[
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 7),
              child: Row(
                children: [
                  TrainingTag(
                    label: 'Superset ${_supersetLabel(first.supersetGroup)}',
                    color: ember,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Alternate sets',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ],
          for (var index = 0; index < group.exercises.length; index++) ...[
            _ExerciseCard(
              exercise: group.exercises[index],
              previous: _previous[group.exercises[index].exerciseId],
              unit: unit,
              highlighted: isSuperset,
              canMoveUp:
                  ordered.indexWhere(
                    (item) => item.id == group.exercises[index].id,
                  ) >
                  0,
              canMoveDown:
                  ordered.indexWhere(
                    (item) => item.id == group.exercises[index].id,
                  ) <
                  ordered.length - 1,
              onAddSet: () => unawaited(_openSet(group.exercises[index])),
              onEditSet: (set) =>
                  unawaited(_openSet(group.exercises[index], existing: set)),
              onToggleSet: (set) =>
                  unawaited(_toggleSet(group.exercises[index], set)),
              onAction: (action) => unawaited(
                _exerciseAction(group.exercises[index], action, workout),
              ),
            ),
            if (index < group.exercises.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  List<_ExerciseGroup> _groupExercises(Workout workout) {
    final ordered = [...workout.exercises]
      ..sort((a, b) => a.position.compareTo(b.position));
    final seenGroups = <int>{};
    final groups = <_ExerciseGroup>[];
    for (final exercise in ordered) {
      if (exercise.supersetGroup > 0) {
        if (seenGroups.contains(exercise.supersetGroup)) continue;
        seenGroups.add(exercise.supersetGroup);
        groups.add(
          _ExerciseGroup(
            exercises: ordered
                .where((item) => item.supersetGroup == exercise.supersetGroup)
                .toList(growable: false),
          ),
        );
      } else {
        groups.add(_ExerciseGroup(exercises: [exercise]));
      }
    }
    return groups;
  }
}

class _ExerciseGroup {
  const _ExerciseGroup({required this.exercises});
  final List<WorkoutExercise> exercises;
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.previous,
    required this.unit,
    required this.highlighted,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onAddSet,
    required this.onEditSet,
    required this.onToggleSet,
    required this.onAction,
  });

  final WorkoutExercise exercise;
  final PreviousPerformance? previous;
  final WeightUnit unit;
  final bool highlighted;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onAddSet;
  final ValueChanged<WorkoutSet> onEditSet;
  final ValueChanged<WorkoutSet> onToggleSet;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previousText = previous?.sets
        .where((set) => set.completed)
        .map((set) => formatSetLoad(set, unit))
        .take(3)
        .join(' · ');
    final targetText = exercise.targetSets > 0
        ? 'Target ${exercise.targetSets} × ${exercise.targetReps}'
              '${exercise.targetWeightKg != null ? ' @ ${formatWeight(exercise.targetWeightKg!, unit)}' : ''}'
        : null;
    return TrainingCard(
      borderColor: highlighted ? ember.withValues(alpha: 0.5) : hairline,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.exercise.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cream,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${exercise.exercise.muscleGroup.label} · '
                          '${exercise.exercise.equipment.label}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                        if (exercise.restSeconds > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${formatRest(exercise.restSeconds)} rest',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: frost,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Exercise options',
                color: panelHigh,
                icon: const Icon(Icons.more_vert_rounded, color: muted),
                onSelected: onAction,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'rest', child: Text('Rest timer')),
                  const PopupMenuItem(
                    value: 'superset',
                    child: Text('Superset group'),
                  ),
                  const PopupMenuItem(
                    value: 'notes',
                    child: Text('Exercise note'),
                  ),
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
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove from workout'),
                  ),
                ],
              ),
            ],
          ),
          if (targetText != null || previousText != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (targetText != null)
                    Text(
                      targetText,
                      style: theme.textTheme.bodySmall?.copyWith(color: ember),
                    ),
                  if (previousText != null && previousText.isNotEmpty)
                    Text(
                      'Last: $previousText',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  if (previous == null)
                    Text(
                      'No previous session',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                ],
              ),
            ),
          ],
          if (exercise.notes.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              exercise.notes,
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (exercise.sets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(
                'No sets yet.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            )
          else
            for (final set in exercise.sets)
              _SetRow(
                set: set,
                unit: unit,
                onTap: () => onEditSet(set),
                onToggle: () => onToggleSet(set),
              ),
          const SizedBox(height: 4),
          TextButton.icon(
            key: Key('add-set-${exercise.id}'),
            onPressed: onAddSet,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add set'),
            style: TextButton.styleFrom(
              foregroundColor: ember,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.set,
    required this.unit,
    required this.onTap,
    required this.onToggle,
  });

  final WorkoutSet set;
  final WeightUnit unit;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rpe = formatRpe(set.rpe);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: set.completed ? ember : hairline),
              ),
              child: Text(
                '${set.position + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: set.completed ? ember : muted,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 9),
            if (set.kind != SetKind.normal) ...[
              TrainingTag(
                label: switch (set.kind) {
                  SetKind.warmup => 'Warm',
                  SetKind.drop => 'Drop',
                  SetKind.failure => 'Fail',
                  SetKind.normal => '',
                },
                color: set.kind == SetKind.failure ? rose : frost,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                formatSetLoad(set, unit),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: set.completed ? cream : muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (rpe.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  rpe,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            if (set.notes.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(right: 2),
                child: Icon(
                  Icons.sticky_note_2_outlined,
                  size: 14,
                  color: muted,
                ),
              ),
            IconButton(
              key: Key('set-complete-${set.id}'),
              tooltip: set.completed ? 'Mark incomplete' : 'Complete set',
              visualDensity: VisualDensity.compact,
              onPressed: onToggle,
              icon: Icon(
                set.completed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: set.completed ? ember : muted,
                size: 21,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestPanel extends StatelessWidget {
  const _RestPanel({required this.controller});

  final RestTimerController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final running = controller.isRunning;
        return Container(
          decoration: const BoxDecoration(
            color: panel,
            border: Border(top: BorderSide(color: hairline)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REST',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: running ? ember : muted,
                                letterSpacing: 1.4,
                              ),
                        ),
                        Text(
                          running
                              ? formatRestClock(controller.remainingSeconds)
                              : '—',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: running ? cream : muted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: running
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: controller.progress,
                              minHeight: 3,
                              backgroundColor: hairline,
                              color: ember,
                            ),
                          )
                        : Text(
                            'Auto-starts after a completed set',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: muted),
                          ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Subtract 15 seconds',
                    onPressed: running
                        ? () => controller.addSeconds(-15)
                        : null,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove_rounded, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Add 15 seconds',
                    onPressed: running ? () => controller.addSeconds(15) : null,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_rounded, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Skip rest',
                    onPressed: running ? controller.skip : null,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.skip_next_rounded, size: 18),
                  ),
                ],
              ),
              if (running) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Music keeps playing',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: frost,
                      fontSize: 9,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

String _supersetLabel(int group) {
  if (group <= 0) return 'None';
  const labels = ['A', 'B', 'C', 'D'];
  return group <= labels.length ? labels[group - 1] : '$group';
}
