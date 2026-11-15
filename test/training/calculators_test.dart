import 'package:flutter_test/flutter_test.dart';

import 'package:altaria/training/calculators.dart';
import 'package:altaria/training/models.dart';
import 'package:altaria/training/seed_exercises.dart';

const bench = Exercise(
  id: 1,
  name: 'Bench',
  muscleGroup: MuscleGroup.chest,
  equipment: Equipment.barbell,
);

WorkoutSet set({
  int id = 1,
  int position = 0,
  SetKind kind = SetKind.normal,
  double weight = 0,
  int reps = 0,
  bool completed = true,
}) {
  return WorkoutSet(
    id: id,
    position: position,
    kind: kind,
    weightKg: weight,
    reps: reps,
    completed: completed,
  );
}

Workout workout({
  required int id,
  required DateTime date,
  required List<WorkoutSet> sets,
  String status = 'finished',
}) {
  return Workout(
    id: id,
    name: 'Session',
    startedAt: date.subtract(const Duration(minutes: 40)),
    finishedAt: status == 'finished' ? date : null,
    status: status,
    exercises: [
      WorkoutExercise(id: id, exercise: bench, position: 0, sets: sets),
    ],
  );
}

void main() {
  group('weight conversion', () {
    test('converts kilograms and pounds both ways', () {
      expect(kgToLb(100), closeTo(220.462262, 0.0001));
      expect(lbToKg(220.462262), closeTo(100, 0.0001));
      expect(convertFromKg(20, WeightUnit.kg), 20);
      expect(convertFromKg(20, WeightUnit.lb), closeTo(44.092, 0.001));
    });

    test('formats stored kilograms in the active unit', () {
      expect(weightValue(100, WeightUnit.kg), '100');
      expect(weightValue(45.359237, WeightUnit.lb), '100');
      expect(formatWeight(0, WeightUnit.kg), '—');
      expect(formatWeight(60, WeightUnit.kg), '60 kg');
    });
  });

  group('one rep max', () {
    test('uses Epley and handles a single', () {
      expect(estimateOneRepMax(100, 5), closeTo(116.6667, 0.001));
      expect(estimateOneRepMax(100, 1), 100);
      expect(estimateOneRepMax(0, 5), 0);
      expect(estimateOneRepMax(100, 0), 0);
    });

    test('builds a descending percentage table', () {
      final table = oneRepMaxTable(100);
      expect(table.first.percent, 100);
      expect(table.first.weightKg, 100);
      expect(table.last.percent, 50);
      expect(table.last.weightKg, 50);
      expect(table, hasLength(11));
    });
  });

  group('plate math', () {
    test('loads an exact pair of plates', () {
      final solution = calculatePlates(
        targetWeightKg: 100,
        barWeightKg: 20,
        availablePlatesKg: const [25, 20, 15, 10, 5, 2.5, 1.25],
      );
      expect(solution.platesKg, [25, 15]);
      expect(solution.achievedWeightKg, 100);
      expect(solution.exact, isTrue);
    });

    test('uses the smallest plate when needed', () {
      final solution = calculatePlates(
        targetWeightKg: 102.5,
        barWeightKg: 20,
        availablePlatesKg: const [25, 20, 15, 10, 5, 2.5, 1.25],
      );
      expect(solution.platesKg, [25, 15, 1.25]);
      expect(solution.achievedWeightKg, 102.5);
      expect(solution.exact, isTrue);
    });

    test(
      'reports the shortfall when the inventory cannot reach the target',
      () {
        final solution = calculatePlates(
          targetWeightKg: 101,
          barWeightKg: 20,
          availablePlatesKg: const [25, 15],
        );
        expect(solution.achievedWeightKg, 100);
        expect(solution.remainderKg, 1);
        expect(solution.exact, isFalse);
        expect(solution.canLoad, isTrue);
      },
    );

    test('rejects a target below the bar', () {
      final solution = calculatePlates(
        targetWeightKg: 15,
        barWeightKg: 20,
        availablePlatesKg: const [10],
      );
      expect(solution.canLoad, isFalse);
      expect(solution.achievedWeightKg, 20);
    });
  });

  group('warm-up percentages', () {
    test('returns four percentages with descending reps', () {
      final sets = warmupSets(100);
      expect(sets.map((set) => set.percent), [40, 60, 80, 90]);
      expect(sets.map((set) => set.weightKg), [40, 60, 80, 90]);
      expect(sets.map((set) => set.reps), [8, 5, 3, 1]);
      expect(warmupSets(0), isEmpty);
    });
  });

  group('volume', () {
    test('counts completed working sets only', () {
      final session = workout(
        id: 1,
        date: DateTime(2026, 1, 1),
        sets: [
          set(weight: 100, reps: 5),
          set(id: 2, kind: SetKind.warmup, weight: 60, reps: 8),
          set(id: 3, weight: 100, reps: 3),
          set(id: 4, weight: 100, reps: 10, completed: false),
        ],
      );
      expect(setVolumeKg(100, 5), 500);
      expect(workoutVolumeKg(session), 800);
      expect(session.exercises.single.completedSets, 3);
    });
  });

  group('personal records', () {
    test('detects weight, estimated max, volume and reps at weight', () {
      final first = workout(
        id: 1,
        date: DateTime(2026, 1, 1),
        sets: [
          set(weight: 100, reps: 5),
          set(id: 2, weight: 110, reps: 1),
          set(id: 3, kind: SetKind.warmup, weight: 140, reps: 1),
          set(id: 4, weight: 130, reps: 1, completed: false),
        ],
      );
      final second = workout(
        id: 2,
        date: DateTime(2026, 1, 8),
        sets: [set(weight: 90, reps: 8), set(id: 2, weight: 120, reps: 1)],
      );

      final records = detectRecords([first, second], [bench]);
      final record = records[bench.id]!;

      expect(record.maxWeight?.weightKg, 120);
      expect(record.maxWeight?.workoutId, 2);
      expect(record.estimatedOneRepMax?.weightKg, 120);
      expect(record.estimatedOneRepMax?.value, 120);
      expect(record.setVolume?.value, 720);
      expect(record.repsAtWeight.first.weightKg, 120);
      expect(
        record.repsAtWeight.firstWhere((entry) => entry.weightKg == 100).reps,
        5,
      );
      expect(record.workoutCount, 2);
    });

    test('only reports records set by the new workout', () {
      final first = workout(
        id: 1,
        date: DateTime(2026, 1, 1),
        sets: [set(weight: 100, reps: 5)],
      );
      final second = workout(
        id: 2,
        date: DateTime(2026, 1, 8),
        sets: [set(weight: 105, reps: 3)],
      );

      final updates = newRecordsForWorkout(
        previousWorkouts: [first],
        workout: second,
        exercises: [bench],
      );

      expect(updates.map((update) => update.label), ['Max weight']);
      expect(updates.single.value, 105);
    });

    test('ignores an unfinished workout', () {
      final active = workout(
        id: 1,
        date: DateTime(2026, 1, 1),
        status: 'active',
        sets: [set(weight: 200, reps: 1)],
      );
      expect(detectRecords([active], [bench]), isEmpty);
    });
  });

  test('the seeded catalogue has 200 or more unique movements', () {
    final names = seedExercises.map((exercise) => exercise.name.toLowerCase());
    expect(seedExercises.length, greaterThanOrEqualTo(200));
    expect(names.toSet(), hasLength(seedExercises.length));
    expect(
      seedExercises.every((exercise) => exercise.cues.trim().isNotEmpty),
      isTrue,
    );
    expect(names, contains('incline chest press'));
  });
}
