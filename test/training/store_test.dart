import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:altaria/training/database.dart';
import 'package:altaria/training/models.dart';
import 'package:altaria/training/notifications.dart';
import 'package:altaria/training/repository.dart';
import 'package:altaria/training/training_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(sqfliteFfiInit);

  late Directory tempDir;
  late String databasePath;
  late TrainingDatabase database;
  late TrainingRepository repository;

  Future<TrainingStore> openStore(NoopRestNotifier notifier) async {
    database = await TrainingDatabase.openWithFactory(
      databaseFactoryFfi,
      databasePath: databasePath,
      singleInstance: false,
    );
    repository = TrainingRepository(database);
    await repository.ensureSeed();
    return TrainingStore.load(repository: repository, notifier: notifier);
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('altaria-store-test');
    databasePath = '${tempDir.path}${Platform.pathSeparator}store.db';
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  test('persists the remembered mode and workout through a restart', () async {
    final notifier = NoopRestNotifier(granted: true);
    final store = await openStore(notifier);
    expect(store.settings.lastMode, AppMode.listen);

    await store.setMode(AppMode.train);
    final exercise = store.exercises.firstWhere(
      (item) => item.name == 'Barbell bench press',
    );
    await store.startEmptyWorkout(name: 'Store session');
    await store.addExercise(exercise);
    final active = store.activeWorkout!;
    await store.addSet(
      active.exercises.single.id,
      const WorkoutSet(
        id: 0,
        position: 0,
        kind: SetKind.normal,
        weightKg: 80,
        reps: 5,
        completed: true,
      ),
    );
    final result = await store.finishActiveWorkout();
    expect(result.workout.setCount, 1);
    expect(result.workout.totalVolumeKg, 400);
    expect(result.newRecords, isNotEmpty);
    expect(store.activeWorkout, isNull);
    expect(store.records[exercise.id]?.maxWeight?.weightKg, 80);

    await database.close();
    final reopened = await openStore(notifier);
    expect(reopened.settings.lastMode, AppMode.train);
    expect(reopened.history, hasLength(1));
    expect(reopened.records[exercise.id]?.maxWeight?.weightKg, 80);
  });

  test('notification preference follows the permission result', () async {
    final notifier = NoopRestNotifier(granted: false);
    final store = await openStore(notifier);

    expect(await store.setRestNotifications(true), isFalse);
    expect(store.settings.restNotifications, isFalse);
    expect(store.notificationsGranted, isFalse);

    notifier.granted = true;
    expect(await store.setRestNotifications(true), isTrue);
    expect(store.settings.restNotifications, isTrue);
    expect(store.notificationsGranted, isTrue);

    expect(await store.setRestNotifications(false), isFalse);
    expect(store.settings.restNotifications, isFalse);
  });

  test('imports a backup through the store and refreshes every view', () async {
    final notifier = NoopRestNotifier(granted: true);
    final store = await openStore(notifier);
    final custom = await store.addCustomExercise(
      name: 'Store custom press',
      muscleGroup: MuscleGroup.chest,
      equipment: Equipment.dumbbell,
    );
    final routine = await store.saveRoutine(
      name: 'Stored routine',
      notes: '',
      exercises: [
        RoutineExercise(
          id: 0,
          exercise: custom,
          position: 0,
          targetSets: 3,
          targetReps: 8,
        ),
      ],
    );
    final backup = await store.exportJson();
    expect(routine.name, 'Stored routine');

    await store.resetLocalData();
    expect(store.routines, isEmpty);
    expect(
      store.exercises.where(
        (exercise) => exercise.name == 'Store custom press',
      ),
      isEmpty,
    );

    await store.importBackup(backup);
    expect(store.routines.single.name, 'Stored routine');
    expect(
      store.exercises.where(
        (exercise) => exercise.name == 'Store custom press',
      ),
      hasLength(1),
    );
  });
}
