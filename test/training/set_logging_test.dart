import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:altaria/theme.dart';
import 'package:altaria/training/database.dart';
import 'package:altaria/training/models.dart';
import 'package:altaria/training/notifications.dart';
import 'package:altaria/training/repository.dart';
import 'package:altaria/training/training_scope.dart';
import 'package:altaria/training/training_store.dart';
import 'package:altaria/training/ui/active_workout_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  late Directory tempDir;
  late TrainingDatabase database;
  late TrainingStore store;
  late WorkoutExercise workoutExercise;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('altaria-set-test');
    database = await TrainingDatabase.openWithFactory(
      databaseFactoryFfi,
      databasePath: '${tempDir.path}${Platform.pathSeparator}set-logging.db',
      singleInstance: false,
    );
    final repository = TrainingRepository(database);
    await repository.ensureSeed();
    store = await TrainingStore.load(
      repository: repository,
      notifier: NoopRestNotifier(granted: true),
    );
    await store.saveSettings(
      store.settings.copyWith(
        keepAwake: false,
        defaultRestSeconds: 0,
        restNotifications: false,
      ),
    );
    final bench = store.exercises.firstWhere(
      (exercise) => exercise.name == 'Barbell bench press',
    );
    await store.startEmptyWorkout(name: 'Widget session');
    await store.addExercise(bench, restSeconds: 0);
    workoutExercise = store.activeWorkout!.exercises.single;
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('logs a weighted set from the active workout', (tester) async {
    tester.view.physicalSize = const Size(900, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      TrainingScope(
        store: store,
        child: MaterialApp(
          theme: buildAltariaTheme(),
          home: const ActiveWorkoutScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Barbell bench press'), findsOneWidget);
    await tester.tap(find.byKey(Key('add-set-${workoutExercise.id}')));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byKey(const Key('set-weight')), '80');
    await tester.enterText(find.byKey(const Key('set-reps')), '5');
    await tester.enterText(
      find.byKey(const Key('set-notes')),
      'Left shoulder felt solid.',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('save-set')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('save-set')));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));

    final sets = store.activeWorkout!.exercises.single.sets;
    expect(sets, hasLength(1));
    expect(find.textContaining('80 kg × 5'), findsOneWidget);
    final saved = sets.single;
    expect(saved.weightKg, 80);
    expect(saved.reps, 5);
    expect(saved.completed, isTrue);
    expect(saved.notes, 'Left shoulder felt solid.');
    expect(store.activeWorkout!.exercises.single.completedSets, 1);
    expect(store.history, isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(store.activeWorkout, isNotNull);
  });
}
