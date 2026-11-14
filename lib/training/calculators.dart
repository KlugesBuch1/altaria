import 'dart:math' as math;

import 'models.dart';

const double poundsPerKilogram = 2.2046226218487757;

double kgToLb(double kilograms) => kilograms * poundsPerKilogram;

double lbToKg(double pounds) => pounds / poundsPerKilogram;

double convertFromKg(double kilograms, WeightUnit unit) =>
    unit == WeightUnit.kg ? kilograms : kgToLb(kilograms);

double convertToKg(double value, WeightUnit unit) =>
    unit == WeightUnit.kg ? value : lbToKg(value);

String weightValue(double kilograms, WeightUnit unit, {int decimals = 1}) {
  final value = convertFromKg(kilograms, unit);
  final rounded = double.parse(value.toStringAsFixed(decimals));
  if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);
  return rounded.toStringAsFixed(decimals).replaceFirst(RegExp(r'0+$'), '');
}

String formatWeight(double kilograms, WeightUnit unit, {int decimals = 1}) {
  if (kilograms == 0) return '—';
  return '${weightValue(kilograms, unit, decimals: decimals)} ${unit.storage}';
}

String formatVolume(double kilograms, WeightUnit unit) {
  final value = convertFromKg(kilograms, unit);
  final compact = value >= 10000
      ? '${(value / 1000).toStringAsFixed(1)}k'
      : value.round().toString();
  return '$compact ${unit.storage}';
}

double estimateOneRepMax(double weightKg, int reps) {
  if (weightKg <= 0 || reps <= 0) return 0;
  if (reps == 1) return weightKg;
  final effectiveReps = math.min(reps, 30);
  return weightKg * (1 + effectiveReps / 30);
}

double setVolumeKg(double weightKg, int reps) {
  if (weightKg <= 0 || reps <= 0) return 0;
  return weightKg * reps;
}

double workoutVolumeKg(Workout workout) {
  var total = 0.0;
  for (final exercise in workout.exercises) {
    total += exercise.volumeKg;
  }
  return total;
}

class PlateSolution {
  const PlateSolution({
    required this.targetWeightKg,
    required this.barWeightKg,
    required this.perSideKg,
    required this.platesKg,
    required this.achievedWeightKg,
  });

  final double targetWeightKg;
  final double barWeightKg;
  final double perSideKg;
  final List<double> platesKg;
  final double achievedWeightKg;

  double get remainderKg => targetWeightKg - achievedWeightKg;

  bool get exact => remainderKg.abs() < 0.005;

  bool get canLoad => targetWeightKg >= barWeightKg;
}

PlateSolution calculatePlates({
  required double targetWeightKg,
  required double barWeightKg,
  required List<double> availablePlatesKg,
}) {
  if (targetWeightKg <= 0) {
    throw ArgumentError.value(
      targetWeightKg,
      'targetWeightKg',
      'Target must be positive',
    );
  }
  if (barWeightKg < 0) {
    throw ArgumentError.value(
      barWeightKg,
      'barWeightKg',
      'Bar cannot be negative',
    );
  }
  final perSide = math.max(0.0, (targetWeightKg - barWeightKg) / 2);
  final sizes = availablePlatesKg.where((plate) => plate > 0).toList()
    ..sort((a, b) => b.compareTo(a));
  final loaded = <double>[];
  var remaining = perSide;
  for (final plate in sizes) {
    if (plate <= remaining + 0.0001) {
      loaded.add(plate);
      remaining -= plate;
    }
  }
  final achieved =
      barWeightKg + loaded.fold<double>(0, (sum, plate) => sum + plate) * 2;
  return PlateSolution(
    targetWeightKg: targetWeightKg,
    barWeightKg: barWeightKg,
    perSideKg: loaded.fold<double>(0, (sum, plate) => sum + plate),
    platesKg: List<double>.unmodifiable(loaded),
    achievedWeightKg: achieved,
  );
}

class WarmupSet {
  const WarmupSet({
    required this.percent,
    required this.weightKg,
    required this.reps,
  });

  final int percent;
  final double weightKg;
  final int reps;
}

List<WarmupSet> warmupSets(double workingWeightKg) {
  if (workingWeightKg <= 0) return const [];
  const percentages = [40, 60, 80, 90];
  const reps = [8, 5, 3, 1];
  final result = <WarmupSet>[];
  for (var index = 0; index < percentages.length; index++) {
    final weight = workingWeightKg * percentages[index] / 100;
    if (weight <= 0) continue;
    if (result.isNotEmpty && result.last.weightKg == weight) continue;
    result.add(
      WarmupSet(
        percent: percentages[index],
        weightKg: weight,
        reps: reps[index],
      ),
    );
  }
  return result;
}

class OneRepMaxRow {
  const OneRepMaxRow({required this.percent, required this.weightKg});

  final int percent;
  final double weightKg;
}

List<OneRepMaxRow> oneRepMaxTable(
  double oneRepMaxKg, {
  int from = 100,
  int to = 50,
  int step = 5,
}) {
  if (oneRepMaxKg <= 0) return const [];
  final rows = <OneRepMaxRow>[];
  for (var percent = from; percent >= to; percent -= step) {
    rows.add(
      OneRepMaxRow(percent: percent, weightKg: oneRepMaxKg * percent / 100),
    );
  }
  return rows;
}

Map<int, ExerciseRecords> detectRecords(
  List<Workout> workouts,
  Iterable<Exercise> exercises,
) {
  final byId = {for (final exercise in exercises) exercise.id: exercise};
  final setsByExercise = <int, List<_RecordedSet>>{};
  final workoutIds = <int, Set<int>>{};

  for (final workout in workouts) {
    if (!workout.isFinished) continue;
    final date = workout.finishedAt ?? workout.startedAt;
    for (final exercise in workout.exercises) {
      for (final set in exercise.sets) {
        if (!set.completed || set.isWarmup || set.reps <= 0) continue;
        setsByExercise
            .putIfAbsent(exercise.exerciseId, () => [])
            .add(
              _RecordedSet(
                set: set,
                exercise: byId[exercise.exerciseId] ?? exercise.exercise,
                date: date,
                workoutId: workout.id,
              ),
            );
        workoutIds
            .putIfAbsent(exercise.exerciseId, () => <int>{})
            .add(workout.id);
      }
    }
  }

  final records = <int, ExerciseRecords>{};
  for (final entry in setsByExercise.entries) {
    final sets = entry.value;
    final exercise = sets.first.exercise;
    _RecordedSet? bestWeight;
    _RecordedSet? bestOneRep;
    _RecordedSet? bestVolume;
    final repsAtWeight = <String, RepAtWeight>{};

    for (final recorded in sets) {
      final weight = recorded.set.weightKg;
      final reps = recorded.set.reps;
      if (bestWeight == null ||
          weight > bestWeight.set.weightKg + 0.0001 ||
          (weight - bestWeight.set.weightKg).abs() < 0.0001 &&
              reps > bestWeight.set.reps) {
        bestWeight = recorded;
      }
      final estimated = estimateOneRepMax(weight, reps);
      if (estimated > 0 &&
          (bestOneRep == null ||
              estimated >
                  estimateOneRepMax(
                    bestOneRep.set.weightKg,
                    bestOneRep.set.reps,
                  ))) {
        bestOneRep = recorded;
      }
      final volume = setVolumeKg(weight, reps);
      if (volume >
          (bestVolume == null
              ? -1
              : setVolumeKg(bestVolume.set.weightKg, bestVolume.set.reps))) {
        bestVolume = recorded;
      }

      final key = weight.toStringAsFixed(3);
      final existing = repsAtWeight[key];
      if (existing == null || reps > existing.reps) {
        repsAtWeight[key] = RepAtWeight(
          weightKg: weight,
          reps: reps,
          achievedAt: recorded.date,
          workoutId: recorded.workoutId,
        );
      }
    }

    final repList = repsAtWeight.values.toList()
      ..sort((a, b) => b.weightKg.compareTo(a.weightKg));
    records[entry.key] = ExerciseRecords(
      exercise: exercise,
      maxWeight: bestWeight == null
          ? null
          : PrEntry(
              value: bestWeight.set.weightKg,
              weightKg: bestWeight.set.weightKg,
              reps: bestWeight.set.reps,
              achievedAt: bestWeight.date,
              workoutId: bestWeight.workoutId,
            ),
      estimatedOneRepMax: bestOneRep == null
          ? null
          : PrEntry(
              value: estimateOneRepMax(
                bestOneRep.set.weightKg,
                bestOneRep.set.reps,
              ),
              weightKg: bestOneRep.set.weightKg,
              reps: bestOneRep.set.reps,
              achievedAt: bestOneRep.date,
              workoutId: bestOneRep.workoutId,
            ),
      setVolume: bestVolume == null
          ? null
          : PrEntry(
              value: setVolumeKg(bestVolume.set.weightKg, bestVolume.set.reps),
              weightKg: bestVolume.set.weightKg,
              reps: bestVolume.set.reps,
              achievedAt: bestVolume.date,
              workoutId: bestVolume.workoutId,
            ),
      repsAtWeight: List<RepAtWeight>.unmodifiable(repList),
      workoutCount: workoutIds[entry.key]?.length ?? 0,
    );
  }
  return records;
}

List<PersonalRecordUpdate> newRecordsForWorkout({
  required List<Workout> previousWorkouts,
  required Workout workout,
  required Iterable<Exercise> exercises,
}) {
  final before = detectRecords(previousWorkouts, exercises);
  final after = detectRecords([...previousWorkouts, workout], exercises);
  final updates = <PersonalRecordUpdate>[];
  for (final entry in after.entries) {
    final prior = before[entry.key];
    final current = entry.value;
    if (_beats(current.maxWeight, prior?.maxWeight, workout.id)) {
      updates.add(
        PersonalRecordUpdate(
          exercise: current.exercise,
          label: 'Max weight',
          value: current.maxWeight!.value,
        ),
      );
    }
    if (_beats(
      current.estimatedOneRepMax,
      prior?.estimatedOneRepMax,
      workout.id,
    )) {
      updates.add(
        PersonalRecordUpdate(
          exercise: current.exercise,
          label: 'Est. 1RM',
          value: current.estimatedOneRepMax!.value,
        ),
      );
    }
    if (_beats(current.setVolume, prior?.setVolume, workout.id)) {
      updates.add(
        PersonalRecordUpdate(
          exercise: current.exercise,
          label: 'Set volume',
          value: current.setVolume!.value,
        ),
      );
    }
  }
  return updates;
}

bool _beats(PrEntry? current, PrEntry? previous, int workoutId) {
  if (current == null || current.workoutId != workoutId) return false;
  if (previous == null) return true;
  return current.value > previous.value + 0.0001;
}

class _RecordedSet {
  const _RecordedSet({
    required this.set,
    required this.exercise,
    required this.date,
    required this.workoutId,
  });

  final WorkoutSet set;
  final Exercise exercise;
  final DateTime date;
  final int workoutId;
}
