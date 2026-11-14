import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:altaria/training/database.dart';
import 'package:altaria/training/models.dart';
import 'package:altaria/training/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  late Directory tempDir;
  late String databasePath;
  late TrainingDatabase database;
  late TrainingRepository repository;

  Future<void> openRepository() async {
    database = await TrainingDatabase.openWithFactory(
      databaseFactoryFfi,
      databasePath: databasePath,
      singleInstance: false,
    );
    repository = TrainingRepository(database);
    await repository.ensureSeed();
  }

  Future<void> reopenRepository() async {
    await database.close();
    await openRepository();
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('altaria-training-test');
    databasePath = '${tempDir.path}${Platform.pathSeparator}training.db';
    await openRepository();
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  test('seeding is idempotent and keeps custom movements', () async {
    final initialCount = await repository.exerciseCount();
    expect(initialCount, greaterThanOrEqualTo(150));

    final custom = await repository.addCustomExercise(
      name: 'Landmine split squat',
      muscleGroup: MuscleGroup.quads,
      equipment: Equipment.barbell,
      cues: 'Hold the bar at the chest and stay tall.',
    );
    expect(custom.custom, isTrue);

    await repository.ensureSeed();
    expect(await repository.exerciseCount(), initialCount + 1);
    final library = await repository.exercises();
    expect(
      library.where((exercise) => exercise.name == 'Landmine split squat'),
      hasLength(1),
    );

    await repository.deleteCustomExercise(custom.id);
    final visible = await repository.exercises();
    expect(visible.where((exercise) => exercise.id == custom.id), isEmpty);

    await reopenRepository();
    expect(await repository.exerciseCount(), initialCount + 1);
    expect(
      (await repository.exercises(includeArchived: true))
          .firstWhere((exercise) => exercise.id == custom.id)
          .archived,
      isTrue,
    );
  });

  test(
    'routines, logged sets and finished workouts survive a reopen',
    () async {
      final library = await repository.exercises();
      final bench = library.firstWhere(
        (exercise) => exercise.name == 'Barbell bench press',
      );
      final row = library.firstWhere(
        (exercise) => exercise.name == 'Seated cable row',
      );

      final routine = await repository.saveRoutine(
        name: 'Push and pull',
        notes: 'Keep the rests honest.',
        exercises: [
          RoutineExercise(
            id: 0,
            exercise: bench,
            position: 0,
            targetSets: 4,
            targetReps: 6,
            targetWeightKg: 80,
            restSeconds: 150,
            supersetGroup: 0,
          ),
          RoutineExercise(
            id: 0,
            exercise: row,
            position: 1,
            targetSets: 3,
            targetReps: 10,
            targetWeightKg: 60,
            restSeconds: 90,
            supersetGroup: 1,
          ),
        ],
      );
      expect(routine.exercises, hasLength(2));
      expect(routine.exercises.first.targetWeightKg, 80);

      final workout = await repository.startWorkoutFromRoutine(routine.id);
      expect(workout.name, 'Push and pull');
      expect(workout.exercises, hasLength(2));
      expect(workout.exercises.first.restSeconds, 150);
      expect(workout.exercises[1].supersetGroup, 1);

      final benchExercise = workout.exercises.first;
      final rowExercise = workout.exercises.last;
      await repository.addSet(
        benchExercise.id,
        const WorkoutSet(
          id: 0,
          position: 0,
          kind: SetKind.normal,
          weightKg: 100,
          reps: 5,
          completed: true,
        ),
      );
      await repository.addSet(
        benchExercise.id,
        const WorkoutSet(
          id: 0,
          position: 0,
          kind: SetKind.warmup,
          weightKg: 60,
          reps: 8,
          completed: true,
        ),
      );
      await repository.addSet(
        rowExercise.id,
        const WorkoutSet(
          id: 0,
          position: 0,
          kind: SetKind.normal,
          weightKg: 80,
          reps: 8,
          completed: true,
          rpe: 8.5,
        ),
      );

      final finished = await repository.finishWorkout(workout.id);
      expect(finished.isFinished, isTrue);
      expect(finished.setCount, 3);
      expect(finished.totalVolumeKg, 1140);
      expect(finished.durationSeconds, greaterThanOrEqualTo(1));
      expect((await repository.workouts()).single.id, workout.id);

      final previous = await repository.previousPerformance(bench.id);
      expect(previous, isNotNull);
      expect(previous!.sets, hasLength(2));

      await reopenRepository();
      final persistedRoutine = await repository.routine(routine.id);
      expect(persistedRoutine?.exercises.first.restSeconds, 150);
      final persistedWorkout = await repository.workout(workout.id);
      expect(persistedWorkout?.setCount, 3);
      expect(persistedWorkout?.totalVolumeKg, 1140);
    },
  );

  test('starts empty, adds exercises, and validates active workouts', () async {
    final workout = await repository.startEmptyWorkout(name: 'Quick session');
    expect(workout.exercises, isEmpty);

    await expectLater(
      repository.startEmptyWorkout(name: 'Another'),
      throwsA(isA<TrainingRepositoryException>()),
    );

    final bench = await repository.exercise(1);
    await repository.addWorkoutExercise(workout.id, bench!);
    final active = await repository.activeWorkout();
    expect(active?.exercises, hasLength(1));

    final first = await repository.addSet(
      active!.exercises.single.id,
      const WorkoutSet(
        id: 0,
        position: 0,
        kind: SetKind.failure,
        weightKg: 90,
        reps: 4,
        completed: true,
        notes: 'Last rep slowed down.',
      ),
    );
    expect(first.id, greaterThan(0));

    await repository.discardWorkout(workout.id);
    expect(await repository.activeWorkout(), isNull);
    expect(await repository.workouts(), isEmpty);
  });

  test('backup export, reset and import restore data and settings', () async {
    final bench = await repository.exercise(1);
    final custom = await repository.addCustomExercise(
      name: 'Cable rear lunge',
      muscleGroup: MuscleGroup.quads,
      equipment: Equipment.cable,
      cues: 'Step back slowly and drive through the front heel.',
    );
    final routine = await repository.saveRoutine(
      name: 'Backup routine',
      notes: 'Imported later.',
      exercises: [
        RoutineExercise(
          id: 0,
          exercise: bench!,
          position: 0,
          targetSets: 5,
          targetReps: 5,
          targetWeightKg: 70,
          restSeconds: 120,
        ),
      ],
    );
    final workout = await repository.startWorkoutFromRoutine(routine.id);
    await repository.addSet(
      workout.exercises.single.id,
      const WorkoutSet(
        id: 0,
        position: 0,
        kind: SetKind.normal,
        weightKg: 70,
        reps: 5,
        completed: true,
      ),
    );
    await repository.finishWorkout(workout.id);
    await repository.addBodyMetric(
      BodyMetric(
        id: 0,
        measuredAt: DateTime(2026, 2, 1, 8),
        weightKg: 81.5,
        waistCm: 84,
        notes: 'Morning.',
      ),
    );
    await repository.addProgressPhoto(
      Uint8List.fromList([1, 2, 3, 4]),
      takenAt: DateTime(2026, 2, 1, 8),
      note: 'Baseline',
    );
    const settings = TrainingSettings(
      unit: WeightUnit.lb,
      defaultRestSeconds: 120,
      keepAwake: false,
      lastMode: AppMode.train,
    );
    await repository.saveSettings(settings);

    final backup = await repository.exportJson();
    final decoded = jsonDecode(backup) as Map<String, dynamic>;
    expect(decoded['format'], 'altaria-backup');
    expect(decoded['exercises'], isA<List<dynamic>>());
    expect((decoded['workouts'] as List).length, 1);
    expect(backup, contains('Cable rear lunge'));

    final csv = await repository.exportCsv();
    expect(csv, contains('Barbell bench press'));
    expect(csv, contains('70.0,5'));

    await repository.resetTrainingData();
    expect(await repository.routine(routine.id), isNull);
    expect(await repository.workouts(), isEmpty);
    expect(await repository.bodyMetrics(), isEmpty);
    expect(await repository.progressPhotos(), isEmpty);
    expect((await repository.loadSettings()).lastMode, AppMode.listen);

    await repository.importBackup(backup);

    final restoredRoutine = await repository.routine(routine.id);
    expect(restoredRoutine?.name, 'Backup routine');
    expect(restoredRoutine?.exercises.single.targetWeightKg, 70);

    final restoredWorkout = await repository.workout(workout.id);
    expect(restoredWorkout?.setCount, 1);
    expect(restoredWorkout?.totalVolumeKg, 350);

    final restoredSettings = await repository.loadSettings();
    expect(restoredSettings.unit, WeightUnit.lb);
    expect(restoredSettings.defaultRestSeconds, 120);
    expect(restoredSettings.keepAwake, isFalse);
    expect(restoredSettings.lastMode, AppMode.train);

    final metrics = await repository.bodyMetrics();
    expect(metrics.single.weightKg, 81.5);
    final photos = await repository.progressPhotos();
    expect(photos.single.bytes, [1, 2, 3, 4]);
    expect(photos.single.note, 'Baseline');

    final restoredCustom = (await repository.exercises()).firstWhere(
      (exercise) => exercise.id == custom.id,
    );
    expect(restoredCustom.name, 'Cable rear lunge');
    expect(restoredCustom.custom, isTrue);
  });

  test('rejects files that are not altaria backups', () async {
    await expectLater(
      repository.importBackup('{"format":"something-else","version":1}'),
      throwsA(isA<TrainingRepositoryException>()),
    );
    await expectLater(
      repository.importBackup('not json'),
      throwsA(isA<TrainingRepositoryException>()),
    );
  });
}
