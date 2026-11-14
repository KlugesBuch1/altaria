import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:altaria/theme.dart';
import 'package:altaria/training/database.dart';
import 'package:altaria/training/notifications.dart';
import 'package:altaria/training/repository.dart';
import 'package:altaria/training/training_scope.dart';
import 'package:altaria/training/training_store.dart';
import 'package:altaria/training/ui/routine_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  late Directory tempDir;
  late TrainingDatabase database;
  late TrainingStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('altaria-routine-test');
    database = await TrainingDatabase.openWithFactory(
      databaseFactoryFfi,
      databasePath: '${tempDir.path}${Platform.pathSeparator}routines.db',
      singleInstance: false,
    );
    final repository = TrainingRepository(database);
    await repository.ensureSeed();
    store = await TrainingStore.load(
      repository: repository,
      notifier: NoopRestNotifier(granted: true),
    );
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('edits a routine with a movement and targets', (tester) async {
    tester.view.physicalSize = const Size(900, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final bench = store.exercises.firstWhere(
      (exercise) => exercise.name == 'Barbell bench press',
    );

    await tester.pumpWidget(
      TrainingScope(
        store: store,
        child: MaterialApp(
          theme: buildAltariaTheme(),
          home: const RoutineEditorScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byKey(const Key('routine-name')), 'Push A');
    await tester.tap(find.byKey(const Key('add-routine-exercise')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Choose movement'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('exercise-search')),
      'Barbell bench press',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(Key('exercise-${bench.id}')));
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.text('Choose movement'), findsNothing);
    expect(find.text('Barbell bench press'), findsWidgets);
    await tester.tap(find.byKey(const Key('routine-exercise-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byKey(const Key('target-sets')), '4');
    await tester.enterText(find.byKey(const Key('target-reps')), '6');
    await tester.enterText(find.byKey(const Key('target-weight')), '80');
    await tester.enterText(find.byKey(const Key('target-rest')), '150');
    await tester.scrollUntilVisible(
      find.byKey(const Key('save-targets')),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('save-targets')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('save-routine')));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.routines, hasLength(1));
    final routine = store.routines.single;
    expect(routine.name, 'Push A');
    expect(routine.exercises, hasLength(1));
    expect(routine.exercises.single.exercise.name, 'Barbell bench press');
    expect(routine.exercises.single.targetSets, 4);
    expect(routine.exercises.single.targetReps, 6);
    expect(routine.exercises.single.targetWeightKg, closeTo(80, 0.001));
    expect(routine.exercises.single.restSeconds, 150);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
