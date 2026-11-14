import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import '../models.dart';
import '../repository.dart';
import '../training_scope.dart';
import 'active_workout_screen.dart';
import 'format.dart';
import 'routine_editor.dart';
import 'widgets.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  int? _startingId;
  int? _busyId;

  Future<void> _create() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const RoutineEditorScreen()),
    );
  }

  Future<void> _edit(Routine routine) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => RoutineEditorScreen(routine: routine)),
    );
  }

  Future<void> _start(Routine routine) async {
    final store = TrainingScope.of(context);
    final active = store.activeWorkout;
    if (active != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${active.name} is still active.'),
            action: SnackBarAction(
              label: 'Resume',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
              ),
            ),
          ),
        );
      return;
    }
    setState(() => _startingId = routine.id);
    try {
      await store.startWorkoutFromRoutine(routine.id);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
      );
    } on TrainingRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start the routine.')),
      );
    } finally {
      if (mounted) setState(() => _startingId = null);
    }
  }

  Future<void> _duplicate(Routine routine) async {
    if (_busyId != null) return;
    setState(() => _busyId = routine.id);
    try {
      await TrainingScope.of(context).duplicateRoutine(routine.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${routine.name} duplicated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(Routine routine) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${routine.name}?',
      message: 'Only the routine is removed. Past workouts stay in History.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await TrainingScope.of(context).deleteRoutine(routine.id);
  }

  void _resumeActive() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainingScope.of(context);
    final routines = store.routines;
    final active = store.activeWorkout;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        TrainingHeader(
          eyebrow: 'Train',
          title: 'Routines',
          subtitle: 'Unlimited, local, and yours. No account in the way.',
          trailing: IconButton.filledTonal(
            key: const Key('create-routine'),
            tooltip: 'New routine',
            onPressed: _create,
            icon: const Icon(Icons.add_rounded),
          ),
        ),
        if (active != null) ...[
          const SizedBox(height: 18),
          TrainingCard(
            color: panelHigh,
            onTap: _resumeActive,
            child: Row(
              children: [
                const Icon(Icons.play_circle_outline_rounded, color: ember),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workout in progress',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: ember, letterSpacing: 1.3),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        active.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${active.completedSetCount} sets logged',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: muted),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        if (routines.isEmpty)
          EmptyPanel(
            icon: Icons.view_agenda_outlined,
            title: 'No routines yet',
            message:
                'A routine keeps exercise order, targets, rest and supersets '
                'together. Build one once, start it in a tap.',
            action: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create a routine'),
            ),
          )
        else
          for (final routine in routines)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RoutineCard(
                routine: routine,
                starting: _startingId == routine.id,
                busy: _busyId == routine.id,
                onStart: () => _start(routine),
                onEdit: () => _edit(routine),
                onDuplicate: () => _duplicate(routine),
                onDelete: () => _delete(routine),
              ),
            ),
        if (routines.isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New routine'),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Routines can be edited, duplicated and deleted without a limit.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.starting,
    required this.busy,
    required this.onStart,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final Routine routine;
  final bool starting;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final totalSets = routine.exercises.fold<int>(
      0,
      (total, exercise) => total + exercise.targetSets,
    );
    final supersets = routine.exercises
        .where((exercise) => exercise.supersetGroup > 0)
        .length;
    return TrainingCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
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
                      routine.name,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: cream, fontSize: 19),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      children: [
                        TrainingTag(
                          label:
                              '${routine.exercises.length} ${routine.exercises.length == 1 ? 'movement' : 'movements'}',
                        ),
                        if (totalSets > 0)
                          TrainingTag(
                            label: '$totalSets target sets',
                            color: ember,
                          ),
                        if (supersets > 0)
                          TrainingTag(
                            label: '$supersets in supersets',
                            color: frost,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: Key('routine-menu-${routine.id}'),
                tooltip: 'Routine options',
                color: panelHigh,
                icon: const Icon(Icons.more_vert_rounded, color: muted),
                enabled: !busy && !starting,
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'duplicate') onDuplicate();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (routine.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              routine.notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: muted),
            ),
          ],
          if (routine.exercises.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              routine.exercises
                  .take(4)
                  .map((exercise) => exercise.exercise.name)
                  .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: muted.withValues(alpha: 0.85), height: 1.3),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                key: Key('routine-start-${routine.id}'),
                onPressed: starting ? null : onStart,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                icon: starting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(starting ? 'Starting' : 'Start workout'),
              ),
              const Spacer(),
              Text(
                'Updated ${formatRelativeDay(routine.updatedAt)}',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: muted, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
