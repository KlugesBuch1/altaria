import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import 'calculators.dart';
import 'database.dart';
import 'models.dart';
import 'seed_exercises.dart';

class TrainingRepositoryException implements Exception {
  const TrainingRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TrainingRepository {
  TrainingRepository(this.database);

  final TrainingDatabase database;
  Database get _db => database.db;

  static const String _settingsKey = 'training_settings';

  Future<void> ensureSeed() async {
    final batch = _db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final seed in seedExercises) {
      batch.insert('exercises', {
        'name': seed.name,
        'muscle_group': seed.muscleGroup,
        'equipment': seed.equipment,
        'cues': seed.cues,
        'is_custom': 0,
        'is_archived': 0,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
    await _db.insert('settings', {
      'key': 'exercise_catalog_version',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> exerciseCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM exercises',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Exercise>> exercises({
    String query = '',
    MuscleGroup? muscleGroup,
    Equipment? equipment,
    bool includeArchived = false,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (!includeArchived) where.add('is_archived = 0');
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      where.add('name LIKE ? COLLATE NOCASE');
      args.add('%$trimmed%');
    }
    if (muscleGroup != null) {
      where.add('muscle_group = ?');
      args.add(muscleGroup.storage);
    }
    if (equipment != null) {
      where.add('equipment = ?');
      args.add(equipment.storage);
    }
    final rows = await _db.query(
      'exercises',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'is_custom DESC, name COLLATE NOCASE',
    );
    return rows.map(_exerciseFromRow).toList(growable: false);
  }

  Future<Exercise?> exercise(int id) async {
    final rows = await _db.query(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _exerciseFromRow(rows.first);
  }

  Future<Exercise> addCustomExercise({
    required String name,
    required MuscleGroup muscleGroup,
    required Equipment equipment,
    String cues = '',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const TrainingRepositoryException('Give the movement a name.');
    }
    final existing = await _db.query(
      'exercises',
      columns: ['id'],
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [cleanName],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw const TrainingRepositoryException(
        'An exercise with that name already exists.',
      );
    }
    final id = await _db.insert('exercises', {
      'name': cleanName,
      'muscle_group': muscleGroup.storage,
      'equipment': equipment.storage,
      'cues': cues.trim(),
      'is_custom': 1,
      'is_archived': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    final created = await exercise(id);
    if (created == null) {
      throw const TrainingRepositoryException('Could not save the exercise.');
    }
    return created;
  }

  Future<Exercise> updateCustomExercise(Exercise exercise) async {
    if (!exercise.custom) {
      throw const TrainingRepositoryException(
        'Built-in movements cannot be edited.',
      );
    }
    final cleanName = exercise.name.trim();
    if (cleanName.isEmpty) {
      throw const TrainingRepositoryException('Give the movement a name.');
    }
    final conflict = await _db.query(
      'exercises',
      columns: ['id'],
      where: 'name = ? COLLATE NOCASE AND id != ?',
      whereArgs: [cleanName, exercise.id],
      limit: 1,
    );
    if (conflict.isNotEmpty) {
      throw const TrainingRepositoryException(
        'An exercise with that name already exists.',
      );
    }
    final changed = await _db.update(
      'exercises',
      {
        'name': cleanName,
        'muscle_group': exercise.muscleGroup.storage,
        'equipment': exercise.equipment.storage,
        'cues': exercise.cues.trim(),
      },
      where: 'id = ? AND is_custom = 1',
      whereArgs: [exercise.id],
    );
    if (changed == 0) {
      throw const TrainingRepositoryException('That exercise was not found.');
    }
    final updated = await this.exercise(exercise.id);
    if (updated == null) {
      throw const TrainingRepositoryException('That exercise was not found.');
    }
    return updated;
  }

  Future<void> deleteCustomExercise(int id) async {
    final changed = await _db.update(
      'exercises',
      {'is_archived': 1},
      where: 'id = ? AND is_custom = 1',
      whereArgs: [id],
    );
    if (changed == 0) {
      throw const TrainingRepositoryException(
        'Only custom exercises can be deleted.',
      );
    }
  }

  Future<List<Routine>> routines() async {
    final rows = await _db.query('routines', orderBy: 'updated_at DESC');
    final result = <Routine>[];
    for (final row in rows) {
      result.add(await _routineFromRow(row));
    }
    return result;
  }

  Future<Routine?> routine(int id) async {
    final rows = await _db.query(
      'routines',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _routineFromRow(rows.first);
  }

  Future<List<RoutineExercise>> _routineExercises(int routineId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT re.*, e.name AS exercise_name, e.muscle_group AS exercise_muscle,
        e.equipment AS exercise_equipment, e.cues AS exercise_cues,
        e.is_custom AS exercise_custom, e.is_archived AS exercise_archived
      FROM routine_exercises re
      JOIN exercises e ON e.id = re.exercise_id
      WHERE re.routine_id = ?
      ORDER BY re.position
    ''',
      [routineId],
    );
    return rows
        .map((row) {
          return RoutineExercise(
            id: _int(row['id']),
            exercise: _exerciseFromJoinedRow(row),
            position: _int(row['position']),
            supersetGroup: _int(row['superset_group']),
            targetSets: _int(row['target_sets']),
            targetReps: _int(row['target_reps']),
            targetWeightKg: _nullableDouble(row['target_weight_kg']),
            restSeconds: _int(row['rest_seconds']),
            notes: _string(row['notes']),
          );
        })
        .toList(growable: false);
  }

  Future<Routine> _routineFromRow(Map<String, Object?> row) async {
    final id = _int(row['id']);
    return Routine(
      id: id,
      name: _string(row['name']),
      notes: _string(row['notes']),
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
      exercises: await _routineExercises(id),
    );
  }

  Future<Routine> saveRoutine({
    int? id,
    required String name,
    required String notes,
    required List<RoutineExercise> exercises,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const TrainingRepositoryException('Give the routine a name.');
    }
    final now = DateTime.now();
    late int routineId;
    await _db.transaction((tx) async {
      if (id == null) {
        routineId = await tx.insert('routines', {
          'name': cleanName,
          'notes': notes.trim(),
          'created_at': now.millisecondsSinceEpoch,
          'updated_at': now.millisecondsSinceEpoch,
        });
      } else {
        final existing = await tx.query(
          'routines',
          columns: ['created_at'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (existing.isEmpty) {
          throw const TrainingRepositoryException(
            'That routine was not found.',
          );
        }
        routineId = id;
        await tx.update(
          'routines',
          {
            'name': cleanName,
            'notes': notes.trim(),
            'updated_at': now.millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await tx.delete(
          'routine_exercises',
          where: 'routine_id = ?',
          whereArgs: [id],
        );
      }
      for (var index = 0; index < exercises.length; index++) {
        final exercise = exercises[index];
        await tx.insert('routine_exercises', {
          'routine_id': routineId,
          'exercise_id': exercise.exerciseId,
          'position': index,
          'superset_group': exercise.supersetGroup,
          'target_sets': exercise.targetSets,
          'target_reps': exercise.targetReps,
          'target_weight_kg': exercise.targetWeightKg,
          'rest_seconds': exercise.restSeconds,
          'notes': exercise.notes.trim(),
        });
      }
    });
    final saved = await routine(routineId);
    if (saved == null) {
      throw const TrainingRepositoryException('Could not save the routine.');
    }
    return saved;
  }

  Future<Routine> duplicateRoutine(int id) async {
    final source = await routine(id);
    if (source == null) {
      throw const TrainingRepositoryException('That routine was not found.');
    }
    final copy = await saveRoutine(
      name: '${source.name} copy',
      notes: source.notes,
      exercises: source.exercises,
    );
    return copy;
  }

  Future<void> deleteRoutine(int id) async {
    await _db.delete('routines', where: 'id = ?', whereArgs: [id]);
  }

  Future<Workout?> activeWorkout() async {
    final rows = await _db.query(
      'workouts',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _workoutFromRow(rows.first);
  }

  Future<bool> hasActiveWorkout() async => await activeWorkout() != null;

  Future<Workout> startEmptyWorkout({String? name}) async {
    return _createWorkout(name: name, exercises: const []);
  }

  Future<Workout> startWorkoutFromRoutine(int routineId) async {
    final routine = await this.routine(routineId);
    if (routine == null) {
      throw const TrainingRepositoryException('That routine was not found.');
    }
    final exercises = routine.exercises
        .map(
          (exercise) => _WorkoutSeed(
            exercise: exercise.exercise,
            restSeconds: exercise.restSeconds,
            supersetGroup: exercise.supersetGroup,
            notes: exercise.notes,
            targetSets: exercise.targetSets,
            targetReps: exercise.targetReps,
            targetWeightKg: exercise.targetWeightKg,
          ),
        )
        .toList(growable: false);
    return _createWorkout(
      name: routine.name,
      routineId: routine.id,
      exercises: exercises,
    );
  }

  Future<Workout> startWorkoutFromWorkout(int workoutId) async {
    final source = await workout(workoutId);
    if (source == null) {
      throw const TrainingRepositoryException('That workout was not found.');
    }
    final exercises = source.exercises
        .map(
          (exercise) => _WorkoutSeed(
            exercise: exercise.exercise,
            restSeconds: exercise.restSeconds,
            supersetGroup: exercise.supersetGroup,
            notes: exercise.notes,
            targetSets: exercise.targetSets,
            targetReps: exercise.targetReps,
            targetWeightKg: exercise.targetWeightKg,
          ),
        )
        .toList(growable: false);
    return _createWorkout(
      name: source.name,
      routineId: source.routineId,
      exercises: exercises,
    );
  }

  Future<Workout> _createWorkout({
    String? name,
    int? routineId,
    required List<_WorkoutSeed> exercises,
  }) async {
    final active = await activeWorkout();
    if (active != null) {
      throw const TrainingRepositoryException(
        'Finish or discard the active workout first.',
      );
    }
    final now = DateTime.now();
    final cleanName = (name ?? '').trim().isEmpty
        ? 'Workout ${now.month}/${now.day}'
        : name!.trim();
    late int workoutId;
    await _db.transaction((tx) async {
      workoutId = await tx.insert('workouts', {
        'name': cleanName,
        'started_at': now.millisecondsSinceEpoch,
        'status': 'active',
        'duration_seconds': 0,
        'total_volume_kg': 0,
        'set_count': 0,
        'notes': '',
        'routine_id': routineId,
      });
      for (var index = 0; index < exercises.length; index++) {
        final exercise = exercises[index];
        await tx.insert('workout_exercises', {
          'workout_id': workoutId,
          'exercise_id': exercise.exercise.id,
          'position': index,
          'superset_group': exercise.supersetGroup,
          'rest_seconds': exercise.restSeconds,
          'notes': exercise.notes,
          'target_sets': exercise.targetSets,
          'target_reps': exercise.targetReps,
          'target_weight_kg': exercise.targetWeightKg,
        });
      }
    });
    final created = await workout(workoutId);
    if (created == null) {
      throw const TrainingRepositoryException('Could not start the workout.');
    }
    return created;
  }

  Future<Workout?> workout(int id) async {
    final rows = await _db.query(
      'workouts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _workoutFromRow(rows.first);
  }

  Future<Workout> _workoutFromRow(Map<String, Object?> row) async {
    final id = _int(row['id']);
    final exerciseRows = await _db.rawQuery(
      '''
      SELECT we.*, e.name AS exercise_name, e.muscle_group AS exercise_muscle,
        e.equipment AS exercise_equipment, e.cues AS exercise_cues,
        e.is_custom AS exercise_custom, e.is_archived AS exercise_archived
      FROM workout_exercises we
      JOIN exercises e ON e.id = we.exercise_id
      WHERE we.workout_id = ?
      ORDER BY we.position
    ''',
      [id],
    );
    final exercises = <WorkoutExercise>[];
    for (final exerciseRow in exerciseRows) {
      final workoutExerciseId = _int(exerciseRow['id']);
      final setRows = await _db.query(
        'workout_sets',
        where: 'workout_exercise_id = ?',
        whereArgs: [workoutExerciseId],
        orderBy: 'position',
      );
      exercises.add(
        WorkoutExercise(
          id: workoutExerciseId,
          exercise: _exerciseFromJoinedRow(exerciseRow),
          position: _int(exerciseRow['position']),
          supersetGroup: _int(exerciseRow['superset_group']),
          restSeconds: _int(exerciseRow['rest_seconds']),
          notes: _string(exerciseRow['notes']),
          targetSets: _int(exerciseRow['target_sets']),
          targetReps: _int(exerciseRow['target_reps']),
          targetWeightKg: _nullableDouble(exerciseRow['target_weight_kg']),
          sets: setRows.map(_setFromRow).toList(growable: false),
        ),
      );
    }
    return Workout(
      id: id,
      name: _string(row['name']),
      startedAt: _date(row['started_at']),
      finishedAt: row['finished_at'] == null ? null : _date(row['finished_at']),
      status: _string(row['status'], fallback: 'active'),
      durationSeconds: _int(row['duration_seconds']),
      totalVolumeKg: _double(row['total_volume_kg']),
      setCount: _int(row['set_count']),
      notes: _string(row['notes']),
      routineId: row['routine_id'] == null ? null : _int(row['routine_id']),
      exercises: List<WorkoutExercise>.unmodifiable(exercises),
    );
  }

  Future<List<Workout>> workouts({bool finishedOnly = true}) async {
    final rows = await _db.query(
      'workouts',
      where: finishedOnly ? 'status = ?' : null,
      whereArgs: finishedOnly ? ['finished'] : null,
      orderBy: 'started_at DESC',
    );
    final result = <Workout>[];
    for (final row in rows) {
      result.add(await _workoutFromRow(row));
    }
    return result;
  }

  Future<void> addWorkoutExercise(
    int workoutId,
    Exercise exercise, {
    int restSeconds = 90,
    int supersetGroup = 0,
    int targetSets = 0,
    int targetReps = 0,
    double? targetWeightKg,
  }) async {
    await _assertActive(workoutId);
    final rows = await _db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) AS position '
      'FROM workout_exercises WHERE workout_id = ?',
      [workoutId],
    );
    final position = _int(rows.first['position']) + 1;
    await _db.insert('workout_exercises', {
      'workout_id': workoutId,
      'exercise_id': exercise.id,
      'position': position,
      'superset_group': supersetGroup,
      'rest_seconds': restSeconds,
      'notes': '',
      'target_sets': targetSets,
      'target_reps': targetReps,
      'target_weight_kg': targetWeightKg,
    });
  }

  Future<void> removeWorkoutExercise(int workoutExerciseId) async {
    final rows = await _db.query(
      'workout_exercises',
      columns: ['workout_id'],
      where: 'id = ?',
      whereArgs: [workoutExerciseId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    await _assertActive(_int(rows.first['workout_id']));
    await _db.delete(
      'workout_exercises',
      where: 'id = ?',
      whereArgs: [workoutExerciseId],
    );
    await _reindexWorkoutExercises(_int(rows.first['workout_id']));
  }

  Future<void> reorderWorkoutExercises(
    int workoutId,
    List<int> workoutExerciseIds,
  ) async {
    await _assertActive(workoutId);
    await _db.transaction((tx) async {
      for (var index = 0; index < workoutExerciseIds.length; index++) {
        await tx.update(
          'workout_exercises',
          {'position': index},
          where: 'id = ? AND workout_id = ?',
          whereArgs: [workoutExerciseIds[index], workoutId],
        );
      }
    });
  }

  Future<void> updateWorkoutExercise(
    WorkoutExercise exercise, {
    int? supersetGroup,
    int? restSeconds,
    String? notes,
  }) async {
    final rows = await _db.query(
      'workout_exercises',
      columns: ['workout_id'],
      where: 'id = ?',
      whereArgs: [exercise.id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    await _assertActive(_int(rows.first['workout_id']));
    await _db.update(
      'workout_exercises',
      {
        'superset_group': supersetGroup ?? exercise.supersetGroup,
        'rest_seconds': restSeconds ?? exercise.restSeconds,
        'notes': notes ?? exercise.notes,
      },
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  Future<WorkoutSet> addSet(int workoutExerciseId, WorkoutSet set) async {
    final rows = await _db.query(
      'workout_exercises',
      columns: ['workout_id'],
      where: 'id = ?',
      whereArgs: [workoutExerciseId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const TrainingRepositoryException(
        'That exercise is not in the workout.',
      );
    }
    await _assertActive(_int(rows.first['workout_id']));
    final positionRows = await _db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) AS position '
      'FROM workout_sets WHERE workout_exercise_id = ?',
      [workoutExerciseId],
    );
    final position = _int(positionRows.first['position']) + 1;
    final id = await _db.insert('workout_sets', {
      'workout_exercise_id': workoutExerciseId,
      'position': position,
      'kind': set.kind.storage,
      'weight_kg': set.weightKg,
      'reps': set.reps,
      'duration_seconds': set.durationSeconds,
      'distance_meters': set.distanceMeters,
      'rpe': set.rpe,
      'completed': set.completed ? 1 : 0,
      'notes': set.notes,
    });
    return set.copyWith(id: id, position: position);
  }

  Future<void> updateSet(WorkoutSet set) async {
    await _db.update(
      'workout_sets',
      {
        'kind': set.kind.storage,
        'weight_kg': set.weightKg,
        'reps': set.reps,
        'duration_seconds': set.durationSeconds,
        'distance_meters': set.distanceMeters,
        'rpe': set.rpe,
        'completed': set.completed ? 1 : 0,
        'notes': set.notes,
      },
      where: 'id = ?',
      whereArgs: [set.id],
    );
  }

  Future<void> deleteSet(int id) async {
    await _db.delete('workout_sets', where: 'id = ?', whereArgs: [id]);
  }

  Future<Workout> finishWorkout(int id) async {
    final session = await workout(id);
    if (session == null) {
      throw const TrainingRepositoryException('That workout was not found.');
    }
    if (session.isFinished) return session;
    final now = DateTime.now();
    final duration = now.difference(session.startedAt).inSeconds;
    await _db.update(
      'workouts',
      {
        'status': 'finished',
        'finished_at': now.millisecondsSinceEpoch,
        'duration_seconds': duration < 1 ? 1 : duration,
        'total_volume_kg': workoutVolumeKg(session),
        'set_count': session.completedSetCount,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    final finished = await workout(id);
    if (finished == null) {
      throw const TrainingRepositoryException('Could not finish the workout.');
    }
    return finished;
  }

  Future<void> discardWorkout(int id) async {
    await _db.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateWorkoutDetails({
    required int id,
    required String name,
    required String notes,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const TrainingRepositoryException('Give the workout a name.');
    }
    await _db.update(
      'workouts',
      {'name': cleanName, 'notes': notes.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteWorkout(int id) async {
    await _db.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

  Future<PreviousPerformance?> previousPerformance(
    int exerciseId, {
    int? excludeWorkoutId,
  }) async {
    final args = <Object?>[exerciseId];
    var exclude = '';
    if (excludeWorkoutId != null) {
      exclude = 'AND w.id != ?';
      args.add(excludeWorkoutId);
    }
    final rows = await _db.rawQuery('''
      SELECT w.id
      FROM workouts w
      JOIN workout_exercises we ON we.workout_id = w.id
      WHERE w.status = 'finished' AND we.exercise_id = ? $exclude
        AND EXISTS (
          SELECT 1 FROM workout_sets ws
          WHERE ws.workout_exercise_id = we.id AND ws.completed = 1
        )
      ORDER BY w.finished_at DESC
      LIMIT 1
    ''', args);
    if (rows.isEmpty) return null;
    final previous = await workout(_int(rows.first['id']));
    if (previous == null) return null;
    for (final exercise in previous.exercises) {
      if (exercise.exerciseId != exerciseId) continue;
      final sets = exercise.sets
          .where((set) => set.completed)
          .toList(growable: false);
      if (sets.isEmpty) continue;
      return PreviousPerformance(
        workout: previous,
        sets: sets,
        exercise: exercise.exercise,
      );
    }
    return null;
  }

  Future<List<BodyMetric>> bodyMetrics() async {
    final rows = await _db.query('body_metrics', orderBy: 'measured_at DESC');
    return rows.map(_bodyMetricFromRow).toList(growable: false);
  }

  Future<void> addBodyMetric(BodyMetric metric) async {
    await _db.insert('body_metrics', {
      'measured_at': metric.measuredAt.millisecondsSinceEpoch,
      'weight_kg': metric.weightKg,
      'body_fat': metric.bodyFat,
      'chest_cm': metric.chestCm,
      'waist_cm': metric.waistCm,
      'hips_cm': metric.hipsCm,
      'arm_cm': metric.armCm,
      'thigh_cm': metric.thighCm,
      'notes': metric.notes.trim(),
    });
  }

  Future<void> deleteBodyMetric(int id) async {
    await _db.delete('body_metrics', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ProgressPhoto>> progressPhotos() async {
    final rows = await _db.query('progress_photos', orderBy: 'taken_at DESC');
    return rows.map(_photoFromRow).toList(growable: false);
  }

  Future<void> addProgressPhoto(
    Uint8List bytes, {
    DateTime? takenAt,
    String note = '',
  }) async {
    await _db.insert('progress_photos', {
      'taken_at': (takenAt ?? DateTime.now()).millisecondsSinceEpoch,
      'bytes': bytes,
      'note': note.trim(),
    });
  }

  Future<void> deleteProgressPhoto(int id) async {
    await _db.delete('progress_photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<int, ExerciseRecords>> personalRecords() async {
    final allExercises = await exercises(includeArchived: true);
    final finished = await workouts();
    return detectRecords(finished, allExercises);
  }

  Future<TrainingSettings> loadSettings() async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_settingsKey],
      limit: 1,
    );
    if (rows.isEmpty) return const TrainingSettings();
    try {
      final decoded = jsonDecode(_string(rows.first['value']));
      if (decoded is Map<String, dynamic>) {
        return TrainingSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return TrainingSettings.fromJson(
          decoded.map((key, value) => MapEntry('$key', value)),
        );
      }
    } on FormatException {
      return const TrainingSettings();
    }
    return const TrainingSettings();
  }

  Future<void> saveSettings(TrainingSettings settings) async {
    await _db.insert('settings', {
      'key': _settingsKey,
      'value': jsonEncode(settings.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> exportJson() async {
    final settings = await loadSettings();
    final allExercises = await exercises(includeArchived: true);
    final allRoutines = await routines();
    final allWorkouts = await workouts(finishedOnly: false);
    final metrics = await bodyMetrics();
    final photos = await progressPhotos();
    final payload = <String, dynamic>{
      'format': 'altaria-backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings.toJson(),
      'exercises': allExercises.map((item) => item.toJson()).toList(),
      'routines': allRoutines.map((item) => item.toJson()).toList(),
      'workouts': allWorkouts.map((item) => item.toJson()).toList(),
      'bodyMetrics': metrics.map((item) => item.toJson()).toList(),
      'photos': photos.map((item) => item.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> importBackup(String raw) async {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const TrainingRepositoryException('That file is not valid JSON.');
    }
    if (decoded is! Map) {
      throw const TrainingRepositoryException('That is not an altaria backup.');
    }
    final json = decoded.map((key, value) => MapEntry('$key', value));
    if (json['format'] != 'altaria-backup') {
      throw const TrainingRepositoryException('That is not an altaria backup.');
    }
    final version = (json['version'] as num?)?.toInt() ?? 0;
    if (version != 1) {
      throw const TrainingRepositoryException(
        'That backup version is not supported.',
      );
    }
    final settings = _map(json['settings']) ?? const <String, dynamic>{};
    final exercises = _list(json['exercises']);
    final routines = _list(json['routines']);
    final workouts = _list(json['workouts']);
    final metrics = _list(json['bodyMetrics']);
    final photos = _list(json['photos']);
    final routineIds = <int>{};
    for (final routine in routines) {
      final id = (routine['id'] as num?)?.toInt();
      if (id != null) routineIds.add(id);
    }

    await _db.transaction((tx) async {
      await tx.delete('settings');
      await tx.delete('progress_photos');
      await tx.delete('body_metrics');
      await tx.delete('workouts');
      await tx.delete('routines');
      await tx.delete('exercises');

      for (final item in exercises) {
        final exercise = Exercise.fromJson(item);
        if (exercise.id <= 0 || exercise.name.trim().isEmpty) {
          throw const TrainingRepositoryException(
            'The backup contains an invalid exercise.',
          );
        }
        await tx.insert('exercises', {
          'id': exercise.id,
          'name': exercise.name.trim(),
          'muscle_group': exercise.muscleGroup.storage,
          'equipment': exercise.equipment.storage,
          'cues': exercise.cues,
          'is_custom': exercise.custom ? 1 : 0,
          'is_archived': exercise.archived ? 1 : 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }

      for (final routineJson in routines) {
        final routineId = (routineJson['id'] as num?)?.toInt();
        if (routineId == null) continue;
        await tx.insert('routines', {
          'id': routineId,
          'name': (routineJson['name'] as String?) ?? 'Routine',
          'notes': (routineJson['notes'] as String?) ?? '',
          'created_at': _dateOrNow(routineJson['createdAt'])
              .millisecondsSinceEpoch,
          'updated_at': _dateOrNow(routineJson['updatedAt'])
              .millisecondsSinceEpoch,
        });
        final routineExercises = _list(routineJson['exercises']);
        for (var index = 0; index < routineExercises.length; index++) {
          final item = routineExercises[index];
          await tx.insert('routine_exercises', {
            'routine_id': routineId,
            'exercise_id': (item['exerciseId'] as num?)?.toInt() ?? 0,
            'position': index,
            'superset_group': (item['supersetGroup'] as num?)?.toInt() ?? 0,
            'target_sets': (item['targetSets'] as num?)?.toInt() ?? 3,
            'target_reps': (item['targetReps'] as num?)?.toInt() ?? 8,
            'target_weight_kg': (item['targetWeightKg'] as num?)?.toDouble(),
            'rest_seconds': (item['restSeconds'] as num?)?.toInt() ?? 90,
            'notes': (item['notes'] as String?) ?? '',
          });
        }
      }

      for (final workoutJson in workouts) {
        final workoutId = (workoutJson['id'] as num?)?.toInt();
        if (workoutId == null) continue;
        final routineId = (workoutJson['routineId'] as num?)?.toInt();
        await tx.insert('workouts', {
          'id': workoutId,
          'name': (workoutJson['name'] as String?) ?? 'Workout',
          'started_at': _dateOrNow(workoutJson['startedAt'])
              .millisecondsSinceEpoch,
          'finished_at': workoutJson['finishedAt'] == null
              ? null
              : _dateOrNow(workoutJson['finishedAt']).millisecondsSinceEpoch,
          'status': (workoutJson['status'] as String?) ?? 'finished',
          'duration_seconds':
              (workoutJson['durationSeconds'] as num?)?.toInt() ?? 0,
          'total_volume_kg':
              (workoutJson['totalVolumeKg'] as num?)?.toDouble() ?? 0,
          'set_count': (workoutJson['setCount'] as num?)?.toInt() ?? 0,
          'notes': (workoutJson['notes'] as String?) ?? '',
          'routine_id': routineIds.contains(routineId) ? routineId : null,
        });
        final workoutExercises = _list(workoutJson['exercises']);
        for (var index = 0; index < workoutExercises.length; index++) {
          final item = workoutExercises[index];
          final workoutExerciseId = await tx.insert('workout_exercises', {
            'workout_id': workoutId,
            'exercise_id': (item['exerciseId'] as num?)?.toInt() ?? 0,
            'position': index,
            'superset_group': (item['supersetGroup'] as num?)?.toInt() ?? 0,
            'rest_seconds': (item['restSeconds'] as num?)?.toInt() ?? 90,
            'notes': (item['notes'] as String?) ?? '',
            'target_sets': (item['targetSets'] as num?)?.toInt() ?? 0,
            'target_reps': (item['targetReps'] as num?)?.toInt() ?? 0,
            'target_weight_kg': (item['targetWeightKg'] as num?)?.toDouble(),
          });
          final sets = _list(item['sets']);
          for (var setIndex = 0; setIndex < sets.length; setIndex++) {
            final set = sets[setIndex];
            await tx.insert('workout_sets', {
              'workout_exercise_id': workoutExerciseId,
              'position': setIndex,
              'kind': (set['kind'] as String?) ?? 'normal',
              'weight_kg': (set['weightKg'] as num?)?.toDouble() ?? 0,
              'reps': (set['reps'] as num?)?.toInt() ?? 0,
              'duration_seconds':
                  (set['durationSeconds'] as num?)?.toInt() ?? 0,
              'distance_meters':
                  (set['distanceMeters'] as num?)?.toDouble() ?? 0,
              'rpe': (set['rpe'] as num?)?.toDouble(),
              'completed': set['completed'] == true ? 1 : 0,
              'notes': (set['notes'] as String?) ?? '',
            });
          }
        }
      }

      for (final metricJson in metrics) {
        final metric = BodyMetric.fromJson(metricJson);
        await tx.insert('body_metrics', {
          'id': metric.id,
          'measured_at': metric.measuredAt.millisecondsSinceEpoch,
          'weight_kg': metric.weightKg,
          'body_fat': metric.bodyFat,
          'chest_cm': metric.chestCm,
          'waist_cm': metric.waistCm,
          'hips_cm': metric.hipsCm,
          'arm_cm': metric.armCm,
          'thigh_cm': metric.thighCm,
          'notes': metric.notes,
        });
      }

      for (final photoJson in photos) {
        final photo = ProgressPhoto.fromJson(photoJson);
        await tx.insert('progress_photos', {
          'id': photo.id,
          'taken_at': photo.takenAt.millisecondsSinceEpoch,
          'bytes': photo.bytes,
          'note': photo.note,
        });
      }

      await tx.insert('settings', {
        'key': _settingsKey,
        'value': jsonEncode(settings),
      });
    });
    await ensureSeed();
  }

  Future<void> resetTrainingData() async {
    await _db.transaction((tx) async {
      await tx.delete('settings');
      await tx.delete('progress_photos');
      await tx.delete('body_metrics');
      await tx.delete('workouts');
      await tx.delete('routines');
      await tx.delete('exercises');
    });
    await ensureSeed();
  }

  Future<String> exportCsv() async {
    final finished = await workouts();
    final rows = <List<String>>[
      [
        'date',
        'workout',
        'exercise',
        'set',
        'kind',
        'weight_kg',
        'reps',
        'duration_seconds',
        'distance_meters',
        'rpe',
        'completed',
        'notes',
      ],
    ];
    for (final workout in finished) {
      final date = (workout.finishedAt ?? workout.startedAt).toIso8601String();
      for (final exercise in workout.exercises) {
        for (var index = 0; index < exercise.sets.length; index++) {
          final set = exercise.sets[index];
          rows.add([
            date,
            workout.name,
            exercise.exercise.name,
            '${index + 1}',
            set.kind.storage,
            set.weightKg.toString(),
            set.reps.toString(),
            set.durationSeconds.toString(),
            set.distanceMeters.toString(),
            set.rpe?.toString() ?? '',
            set.completed ? 'yes' : 'no',
            set.notes,
          ]);
        }
      }
    }
    return rows.map((row) => row.map(_csvField).join(',')).join('\n');
  }

  Future<void> _assertActive(int workoutId) async {
    final rows = await _db.query(
      'workouts',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [workoutId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const TrainingRepositoryException('That workout was not found.');
    }
    if (_string(rows.first['status']) != 'active') {
      throw const TrainingRepositoryException(
        'That workout has already finished.',
      );
    }
  }

  Future<void> _reindexWorkoutExercises(int workoutId) async {
    final rows = await _db.query(
      'workout_exercises',
      columns: ['id'],
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'position',
    );
    await _db.transaction((tx) async {
      for (var index = 0; index < rows.length; index++) {
        await tx.update(
          'workout_exercises',
          {'position': index},
          where: 'id = ?',
          whereArgs: [_int(rows[index]['id'])],
        );
      }
    });
  }
}

class _WorkoutSeed {
  const _WorkoutSeed({
    required this.exercise,
    required this.restSeconds,
    required this.supersetGroup,
    required this.notes,
    required this.targetSets,
    required this.targetReps,
    required this.targetWeightKg,
  });

  final Exercise exercise;
  final int restSeconds;
  final int supersetGroup;
  final String notes;
  final int targetSets;
  final int targetReps;
  final double? targetWeightKg;
}

Exercise _exerciseFromRow(Map<String, Object?> row) {
  return Exercise(
    id: _int(row['id']),
    name: _string(row['name']),
    muscleGroup: MuscleGroup.parse(row['muscle_group']),
    equipment: Equipment.parse(row['equipment']),
    cues: _string(row['cues']),
    custom: _int(row['is_custom']) == 1,
    archived: _int(row['is_archived']) == 1,
  );
}

Exercise _exerciseFromJoinedRow(Map<String, Object?> row) {
  return Exercise(
    id: _int(row['exercise_id']),
    name: _string(row['exercise_name']),
    muscleGroup: MuscleGroup.parse(row['exercise_muscle']),
    equipment: Equipment.parse(row['exercise_equipment']),
    cues: _string(row['exercise_cues']),
    custom: _int(row['exercise_custom']) == 1,
    archived: _int(row['exercise_archived']) == 1,
  );
}

WorkoutSet _setFromRow(Map<String, Object?> row) {
  return WorkoutSet(
    id: _int(row['id']),
    position: _int(row['position']),
    kind: SetKind.parse(row['kind']),
    weightKg: _double(row['weight_kg']),
    reps: _int(row['reps']),
    durationSeconds: _int(row['duration_seconds']),
    distanceMeters: _double(row['distance_meters']),
    rpe: _nullableDouble(row['rpe']),
    completed: _int(row['completed']) == 1,
    notes: _string(row['notes']),
  );
}

BodyMetric _bodyMetricFromRow(Map<String, Object?> row) {
  return BodyMetric(
    id: _int(row['id']),
    measuredAt: _date(row['measured_at']),
    weightKg: _nullableDouble(row['weight_kg']),
    bodyFat: _nullableDouble(row['body_fat']),
    chestCm: _nullableDouble(row['chest_cm']),
    waistCm: _nullableDouble(row['waist_cm']),
    hipsCm: _nullableDouble(row['hips_cm']),
    armCm: _nullableDouble(row['arm_cm']),
    thighCm: _nullableDouble(row['thigh_cm']),
    notes: _string(row['notes']),
  );
}

ProgressPhoto _photoFromRow(Map<String, Object?> row) {
  final value = row['bytes'];
  return ProgressPhoto(
    id: _int(row['id']),
    takenAt: _date(row['taken_at']),
    bytes: value is Uint8List
        ? value
        : value is List<int>
        ? Uint8List.fromList(value)
        : Uint8List(0),
    note: _string(row['note']),
  );
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

int _int(Object? value) => value is num ? value.toInt() : 0;

double _double(Object? value) => value is num ? value.toDouble() : 0;

double? _nullableDouble(Object? value) =>
    value is num ? value.toDouble() : null;

DateTime _date(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch(value is num ? value.toInt() : 0);

DateTime _dateOrNow(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  return null;
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) {
        return item.map((key, value) => MapEntry('$key', value));
      })
      .toList(growable: false);
}

String _csvField(String value) {
  if (!value.contains(RegExp('[,"\\n\\r]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}
