import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import '../calculators.dart';
import '../models.dart';
import '../training_scope.dart';
import 'charts.dart';
import 'widgets.dart';

class ExerciseProgressScreen extends StatelessWidget {
  const ExerciseProgressScreen({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  Widget build(BuildContext context) {
    final store = TrainingScope.of(context);
    final unit = store.settings.unit;
    final record = store.records[exerciseId];
    if (record == null || !record.hasSets) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text(
            'No completed sets for this movement yet.',
            style: TextStyle(color: muted),
          ),
        ),
      );
    }
    final topSets = _topSetPoints(store.history, exerciseId);
    final volumes = _volumePoints(store.history, exerciseId);
    final hasWeight =
        record.maxWeight?.weightKg != null && record.maxWeight!.weightKg > 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise progress')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          TrainingTag(label: record.exercise.muscleGroup.label),
          const SizedBox(height: 8),
          Text(
            record.exercise.name,
            style: Theme.of(context).textTheme.displaySmall
                ?.copyWith(color: cream, fontSize: 29),
          ),
          const SizedBox(height: 4),
          Text(
            '${record.workoutCount} ${record.workoutCount == 1 ? 'session' : 'sessions'} with completed sets',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted),
          ),
          const SizedBox(height: 18),
          TrainingCard(
            child: Row(
              children: [
                Expanded(
                  child: StatCell(
                    value: record.maxWeight == null
                        ? '—'
                        : hasWeight
                        ? formatWeight(record.maxWeight!.weightKg, unit)
                        : '${record.maxWeight!.reps} reps',
                    label: 'Best set',
                    accent: ember,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: record.estimatedOneRepMax == null
                        ? '—'
                        : formatWeight(record.estimatedOneRepMax!.value, unit),
                    label: 'Est. 1RM',
                    accent: frost,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: record.setVolume == null
                        ? '—'
                        : formatVolume(record.setVolume!.value, unit),
                    label: 'Set volume',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TrainingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TrainingSectionTitle(title: 'Top set over time'),
                const SizedBox(height: 12),
                TrainingLineChart(
                  points: topSets,
                  unit: hasWeight ? unit.storage : 'reps',
                  color: ember,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TrainingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TrainingSectionTitle(title: 'Volume per session'),
                const SizedBox(height: 12),
                TrainingLineChart(
                  points: volumes,
                  unit: unit.storage,
                  color: frost,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const TrainingSectionTitle(title: 'Reps at weight'),
          const SizedBox(height: 8),
          if (record.repsAtWeight.isEmpty)
            Text(
              'No weighted sets recorded.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: muted),
            )
          else
            TrainingCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < record.repsAtWeight.length;
                    index++
                  ) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.repsAtWeight[index].weightKg > 0
                                  ? formatWeight(
                                      record.repsAtWeight[index].weightKg,
                                      unit,
                                    )
                                  : 'Bodyweight',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: cream),
                            ),
                          ),
                          Text(
                            '${record.repsAtWeight[index].reps} reps',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: muted,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (index < record.repsAtWeight.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 18),
          Text(
            'Charts use finished sessions only. Warm-ups do not count.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

List<ChartPoint> _topSetPoints(List<Workout> history, int exerciseId) {
  final workouts = [...history]
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final points = <ChartPoint>[];
  for (final workout in workouts) {
    WorkoutExercise? match;
    for (final exercise in workout.exercises) {
      if (exercise.exerciseId == exerciseId) {
        match = exercise;
        break;
      }
    }
    if (match == null) continue;
    final sets = match.sets.where((set) => set.completed && !set.isWarmup);
    if (sets.isEmpty) continue;
    final weighted = sets.where((set) => set.weightKg > 0).toList();
    double value;
    if (weighted.isNotEmpty) {
      value = weighted.map((set) => set.weightKg).reduce(math.max);
    } else {
      value = sets.map((set) => set.reps).reduce(math.max).toDouble();
    }
    points.add(
      ChartPoint(
        date: (workout.finishedAt ?? workout.startedAt).toLocal(),
        value: value,
      ),
    );
  }
  return points;
}

List<ChartPoint> _volumePoints(List<Workout> history, int exerciseId) {
  final workouts = [...history]
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final points = <ChartPoint>[];
  for (final workout in workouts) {
    for (final exercise in workout.exercises) {
      if (exercise.exerciseId != exerciseId) continue;
      if (exercise.sets.where((set) => set.completed).isEmpty) continue;
      points.add(
        ChartPoint(
          date: (workout.finishedAt ?? workout.startedAt).toLocal(),
          value: exercise.volumeKg,
        ),
      );
      break;
    }
  }
  return points;
}
