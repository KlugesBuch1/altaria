import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import '../models.dart';
import '../repository.dart';
import '../calculators.dart';
import '../training_scope.dart';
import 'active_workout_screen.dart';
import 'calculator_screens.dart';
import 'exercise_library_screen.dart';
import 'format.dart';
import 'routines_screen.dart';
import 'settings_screen.dart';
import 'tools_screen.dart';
import 'widgets.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, this.onOpenRoutines, this.onOpenHistory});

  final VoidCallback? onOpenRoutines;
  final VoidCallback? onOpenHistory;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  bool _busy = false;

  void _openRoutines() {
    final callback = widget.onOpenRoutines;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const RoutinesScreen()));
  }

  void _openHistory() {
    final callback = widget.onOpenHistory;
    if (callback != null) {
      callback();
    }
  }

  Future<void> _openActive() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
    );
  }

  Future<void> _startEmpty() async {
    if (_busy) return;
    final store = TrainingScope.of(context);
    if (store.activeWorkout != null) {
      await _openActive();
      return;
    }
    setState(() => _busy = true);
    try {
      await store.startEmptyWorkout();
      if (!mounted) return;
      await _openActive();
    } on TrainingRepositoryException catch (error) {
      if (!mounted) return;
      _toast(error.message);
    } catch (_) {
      if (!mounted) return;
      _toast('Could not start a workout.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startRoutine(Routine routine) async {
    if (_busy) return;
    final store = TrainingScope.of(context);
    if (store.activeWorkout != null) {
      await _openActive();
      return;
    }
    setState(() => _busy = true);
    try {
      await store.startWorkoutFromRoutine(routine.id);
      if (!mounted) return;
      await _openActive();
    } on TrainingRepositoryException catch (error) {
      if (!mounted) return;
      _toast(error.message);
    } catch (_) {
      if (!mounted) return;
      _toast('Could not start the routine.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _repeat(Workout workout) async {
    if (_busy) return;
    final store = TrainingScope.of(context);
    if (store.activeWorkout != null) {
      await _openActive();
      return;
    }
    setState(() => _busy = true);
    try {
      await store.repeatWorkout(workout.id);
      if (!mounted) return;
      await _openActive();
    } on TrainingRepositoryException catch (error) {
      if (!mounted) return;
      _toast(error.message);
    } catch (_) {
      if (!mounted) return;
      _toast('Could not repeat that workout.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _push(Widget screen) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainingScope.of(context);
    final active = store.activeWorkout;
    final routines = store.routines;
    final recent = store.history.isEmpty ? null : store.history.first;
    final unit = store.settings.unit;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        TrainingHeader(
          eyebrow: 'Train',
          title: 'Workout',
          subtitle: 'Start a session and log each set.',
          trailing: IconButton.filledTonal(
            tooltip: 'Settings',
            onPressed: () => _push(const SettingsScreen()),
            icon: const Icon(Icons.settings_outlined),
          ),
        ),
        const SizedBox(height: 18),
        if (active != null)
          _ActiveWorkoutCard(workout: active, unit: unit, onResume: _openActive)
        else
          TrainingCard(
            color: panelHigh,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const TrainingTag(label: 'Open session'),
                    const Spacer(),
                    Icon(
                      Icons.fitness_center_rounded,
                      color: ember.withValues(alpha: 0.7),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Start from zero.',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: cream, height: 1.05),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick movements as you go. No routine needed, no setup.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('start-empty-workout'),
                    onPressed: _busy ? null : _startEmpty,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start empty workout'),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 22),
        TrainingSectionTitle(
          title: 'From a routine',
          action: TextButton(
            onPressed: _openRoutines,
            child: const Text('All routines'),
          ),
        ),
        const SizedBox(height: 8),
        if (routines.isEmpty)
          TrainingCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                const Icon(Icons.view_agenda_outlined, color: muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No routines yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Build one when you want a repeatable session.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _openRoutines,
                  child: const Text('Build'),
                ),
              ],
            ),
          )
        else
          for (var index = 0; index < routines.take(3).length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RoutineQuickStart(
                routine: routines[index],
                onStart: () => _startRoutine(routines[index]),
              ),
            ),
        if (routines.length > 3)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _openRoutines,
              child: Text('${routines.length - 3} more routines'),
            ),
          ),
        const SizedBox(height: 22),
        const TrainingSectionTitle(title: 'Tools'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.55,
          children: [
            DashboardButton(
              icon: Icons.donut_large_rounded,
              label: 'Plate calculator',
              onTap: () => _push(const PlateCalculatorScreen()),
            ),
            DashboardButton(
              icon: Icons.bolt_rounded,
              label: 'Warm-up sets',
              onTap: () => _push(const WarmupCalculatorScreen()),
            ),
            DashboardButton(
              icon: Icons.percent_rounded,
              label: '1RM table',
              onTap: () => _push(const OneRepMaxScreen()),
            ),
            DashboardButton(
              icon: Icons.menu_book_rounded,
              label: 'Movements',
              onTap: () => _push(const ExerciseLibraryScreen()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _push(const ToolsScreen()),
            icon: const Icon(Icons.grid_view_rounded, size: 17),
            label: const Text('All tools & setup'),
          ),
        ),
        if (recent != null) ...[
          const SizedBox(height: 16),
          TrainingSectionTitle(
            title: 'Recent',
            action: TextButton(
              onPressed: _openHistory,
              child: const Text('History'),
            ),
          ),
          const SizedBox(height: 8),
          TrainingCard(
            padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recent.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: cream),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${formatRelativeDay(recent.finishedAt ?? recent.startedAt)} · '
                        '${recent.setCount} sets · '
                        '${formatVolume(recent.totalVolumeKg, unit)}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _repeat(recent),
                  child: const Text('Repeat'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ActiveWorkoutCard extends StatelessWidget {
  const _ActiveWorkoutCard({
    required this.workout,
    required this.unit,
    required this.onResume,
  });

  final Workout workout;
  final WeightUnit unit;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(workout.startedAt).inSeconds;
    return TrainingCard(
      color: panelHigh,
      borderColor: ember.withValues(alpha: 0.5),
      onTap: onResume,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TrainingTag(label: 'In progress', color: ember),
              const Spacer(),
              Text(
                formatTrainingDuration(elapsed),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: frost,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            workout.name,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: cream, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            '${workout.completedSetCount} sets · '
            '${formatVolume(workoutVolumeKg(workout), unit)} logged',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Resume workout'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineQuickStart extends StatelessWidget {
  const _RoutineQuickStart({required this.routine, required this.onStart});

  final Routine routine;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return TrainingCard(
      onTap: onStart,
      padding: const EdgeInsets.fromLTRB(14, 11, 6, 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: wine,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: cream, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routine.name,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: cream, fontSize: 15),
                ),
                Text(
                  '${routine.exercises.length} movements · '
                  '${routine.exercises.fold<int>(0, (total, exercise) => total + exercise.targetSets)} target sets',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: muted),
        ],
      ),
    );
  }
}
