import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import '../calculators.dart';
import '../models.dart';
import '../training_scope.dart';
import 'active_workout_screen.dart';
import 'format.dart';
import 'widgets.dart';

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final int workoutId;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  bool _busy = false;

  Future<void> _edit(Workout workout) async {
    final name = TextEditingController(text: workout.name);
    final notes = TextEditingController(text: workout.notes);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panelHigh,
        title: const Text('Edit workout'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FieldLabel('Name'),
              TextField(
                key: const Key('workout-name'),
                controller: name,
                decoration: const InputDecoration(hintText: 'Workout name'),
              ),
              const SizedBox(height: 12),
              const FieldLabel('Notes'),
              TextField(
                key: const Key('workout-notes'),
                controller: notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Optional note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != true || !mounted) {
      name.dispose();
      notes.dispose();
      return;
    }
    try {
      await TrainingScope.of(context).updateWorkoutDetails(
        id: workout.id,
        name: name.text,
        notes: notes.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Workout updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      name.dispose();
      notes.dispose();
    }
  }

  Future<void> _repeat(Workout workout) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await TrainingScope.of(context).repeatWorkout(workout.id);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _delete(Workout workout) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${workout.name}?',
      message: 'The sets, volume and records from this session are removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await TrainingScope.of(context).deleteWorkout(workout.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainingScope.of(context);
    final workout = store.history.where((item) => item.id == widget.workoutId);
    if (workout.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text(
            'This workout was deleted.',
            style: TextStyle(color: muted),
          ),
        ),
      );
    }
    final item = workout.first;
    final unit = store.settings.unit;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout'),
        actions: [
          IconButton(
            tooltip: 'Repeat workout',
            onPressed: _busy ? null : () => _repeat(item),
            icon: const Icon(Icons.replay_rounded),
          ),
          PopupMenuButton<String>(
            color: panelHigh,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'edit') _edit(item);
              if (value == 'delete') _delete(item);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit name & notes')),
              PopupMenuItem(value: 'delete', child: Text('Delete workout')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TrainingTag(
              label: formatWeekdayDate(
                (item.finishedAt ?? item.startedAt).toLocal(),
              ),
              color: frost,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.name,
            style: Theme.of(context).textTheme.displaySmall
                ?.copyWith(color: cream, fontSize: 30),
          ),
          const SizedBox(height: 16),
          TrainingCard(
            child: Row(
              children: [
                Expanded(
                  child: StatCell(
                    value: formatTrainingDuration(item.durationSeconds),
                    label: 'Duration',
                    accent: frost,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: '${item.setCount}',
                    label: 'Sets',
                    accent: ember,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: formatVolume(item.totalVolumeKg, unit),
                    label: 'Volume',
                  ),
                ),
              ],
            ),
          ),
          if (item.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            TrainingCard(
              color: panelHigh,
              child: Text(
                item.notes,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: cream, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 22),
          const TrainingSectionTitle(title: 'Movements'),
          const SizedBox(height: 10),
          if (item.exercises.isEmpty)
            Text(
              'No movements in this session.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: muted),
            )
          else
            for (final exercise in item.exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TrainingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exercise.exercise.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: cream),
                            ),
                          ),
                          if (exercise.supersetGroup > 0)
                            TrainingTag(
                              label:
                                  'Superset ${String.fromCharCode(64 + exercise.supersetGroup)}',
                              color: ember,
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${exercise.completedSets} sets · '
                        '${formatVolume(exercise.volumeKg, unit)}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: muted),
                      ),
                      if (exercise.notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          exercise.notes,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: muted,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                      if (exercise.sets.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'No sets recorded.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: muted),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        for (final set in exercise.sets)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  child: Text(
                                    '${set.position + 1}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: muted),
                                  ),
                                ),
                                if (set.kind != SetKind.normal)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: TrainingTag(
                                      label: set.kind.label,
                                      color: set.kind == SetKind.failure
                                          ? rose
                                          : frost,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    formatSetLoad(set, unit),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: set.completed ? cream : muted,
                                        ),
                                  ),
                                ),
                                if (set.rpe != null)
                                  Text(
                                    formatRpe(set.rpe),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: muted),
                                  ),
                                if (set.notes.isNotEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: Icon(
                                      Icons.sticky_note_2_outlined,
                                      size: 14,
                                      color: muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _repeat(item),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.replay_rounded, size: 18),
            label: const Text('Repeat this workout'),
          ),
        ],
      ),
    );
  }
}
