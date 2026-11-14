import 'package:flutter/foundation.dart';

import 'calculators.dart';
import 'models.dart';
import 'notifications.dart';
import 'repository.dart';

class WorkoutFinishResult {
  const WorkoutFinishResult({required this.workout, required this.newRecords});

  final Workout workout;
  final List<PersonalRecordUpdate> newRecords;
}

class TrainingStore extends ChangeNotifier {
  TrainingStore({required this.repository, required this.notifier});

  final TrainingRepository repository;
  final RestNotifier notifier;

  TrainingSettings _settings = const TrainingSettings();
  List<Exercise> _exercises = const [];
  List<Routine> _routines = const [];
  List<Workout> _history = const [];
  Workout? _activeWorkout;
  Map<int, ExerciseRecords> _records = const {};
  List<BodyMetric> _bodyMetrics = const [];
  List<ProgressPhoto> _photos = const [];
  bool _loading = true;
  bool? _notificationsGranted;
  String? _error;

  TrainingSettings get settings => _settings;

  List<Exercise> get exercises => _exercises;

  List<Routine> get routines => _routines;

  List<Workout> get history => _history;

  Workout? get activeWorkout => _activeWorkout;

  Map<int, ExerciseRecords> get records => _records;

  List<BodyMetric> get bodyMetrics => _bodyMetrics;

  List<ProgressPhoto> get photos => _photos;

  bool get loading => _loading;

  bool? get notificationsGranted => _notificationsGranted;

  String? get error => _error;

  static Future<TrainingStore> load({
    required TrainingRepository repository,
    required RestNotifier notifier,
  }) async {
    final store = TrainingStore(repository: repository, notifier: notifier);
    await store.refreshAll();
    return store;
  }

  Future<void> refreshAll() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _settings = await repository.loadSettings();
      _exercises = await repository.exercises();
      _routines = await repository.routines();
      _history = await repository.workouts();
      _activeWorkout = await repository.activeWorkout();
      _records = await repository.personalRecords();
      _bodyMetrics = await repository.bodyMetrics();
      _photos = await repository.progressPhotos();
    } catch (error) {
      _error = _messageFor(error);
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> setMode(AppMode mode) async {
    if (_settings.lastMode == mode) return;
    _settings = _settings.copyWith(lastMode: mode);
    notifyListeners();
    await repository.saveSettings(_settings);
  }

  Future<void> saveSettings(TrainingSettings settings) async {
    _settings = settings;
    notifyListeners();
    await repository.saveSettings(settings);
  }

  Future<bool> refreshNotificationPermission() async {
    final granted = await notifier.permissionGranted();
    _notificationsGranted = granted;
    notifyListeners();
    return granted;
  }

  Future<bool> requestNotificationPermission() async {
    final granted = await notifier.requestPermission();
    _notificationsGranted = granted;
    notifyListeners();
    return granted;
  }

  Future<bool> ensureRestNotificationPermission() async {
    if (!_settings.restNotifications) return false;
    if (_notificationsGranted == true) return true;
    final granted = await notifier.requestPermission();
    _notificationsGranted = granted;
    notifyListeners();
    return granted;
  }

  Future<bool> setRestNotifications(bool enabled) async {
    var granted = _notificationsGranted;
    if (enabled) {
      granted = await notifier.requestPermission();
      _notificationsGranted = granted;
    }
    _settings = _settings.copyWith(
      restNotifications: enabled && (granted ?? false),
    );
    notifyListeners();
    await repository.saveSettings(_settings);
    return _settings.restNotifications;
  }

  Future<Exercise> addCustomExercise({
    required String name,
    required MuscleGroup muscleGroup,
    required Equipment equipment,
    String cues = '',
  }) async {
    final exercise = await repository.addCustomExercise(
      name: name,
      muscleGroup: muscleGroup,
      equipment: equipment,
      cues: cues,
    );
    await _refreshExercises();
    return exercise;
  }

  Future<Exercise> updateCustomExercise(Exercise exercise) async {
    final updated = await repository.updateCustomExercise(exercise);
    await _refreshExercises();
    return updated;
  }

  Future<void> deleteCustomExercise(int id) async {
    await repository.deleteCustomExercise(id);
    await _refreshExercises();
  }

  Future<void> _refreshExercises() async {
    _exercises = await repository.exercises();
    _records = await repository.personalRecords();
    notifyListeners();
  }

  Future<Routine> saveRoutine({
    int? id,
    required String name,
    required String notes,
    required List<RoutineExercise> exercises,
  }) async {
    final saved = await repository.saveRoutine(
      id: id,
      name: name,
      notes: notes,
      exercises: exercises,
    );
    _routines = await repository.routines();
    notifyListeners();
    return saved;
  }

  Future<Routine> duplicateRoutine(int id) async {
    final copy = await repository.duplicateRoutine(id);
    _routines = await repository.routines();
    notifyListeners();
    return copy;
  }

  Future<void> deleteRoutine(int id) async {
    await repository.deleteRoutine(id);
    _routines = await repository.routines();
    notifyListeners();
  }

  Future<Workout> startEmptyWorkout({String? name}) async {
    final workout = await repository.startEmptyWorkout(name: name);
    _activeWorkout = workout;
    notifyListeners();
    return workout;
  }

  Future<Workout> startWorkoutFromRoutine(int routineId) async {
    final workout = await repository.startWorkoutFromRoutine(routineId);
    _activeWorkout = workout;
    notifyListeners();
    return workout;
  }

  Future<Workout> repeatWorkout(int workoutId) async {
    final workout = await repository.startWorkoutFromWorkout(workoutId);
    _activeWorkout = workout;
    notifyListeners();
    return workout;
  }

  Future<void> reloadActiveWorkout() async {
    _activeWorkout = await repository.activeWorkout();
    notifyListeners();
  }

  Future<WorkoutSet> addSet(int workoutExerciseId, WorkoutSet set) async {
    final saved = await repository.addSet(workoutExerciseId, set);
    _activeWorkout = await repository.activeWorkout();
    notifyListeners();
    return saved;
  }

  Future<void> updateSet(WorkoutSet set) async {
    await repository.updateSet(set);
    _activeWorkout = await repository.activeWorkout();
    notifyListeners();
  }

  Future<void> deleteSet(int id) async {
    await repository.deleteSet(id);
    _activeWorkout = await repository.activeWorkout();
    notifyListeners();
  }

  Future<void> addExercise(
    Exercise exercise, {
    int? restSeconds,
    int supersetGroup = 0,
  }) async {
    final workout = _activeWorkout;
    if (workout == null) return;
    await repository.addWorkoutExercise(
      workout.id,
      exercise,
      restSeconds: restSeconds ?? _settings.defaultRestSeconds,
      supersetGroup: supersetGroup,
    );
    await reloadActiveWorkout();
  }

  Future<void> removeExercise(int workoutExerciseId) async {
    await repository.removeWorkoutExercise(workoutExerciseId);
    await reloadActiveWorkout();
  }

  Future<void> reorderExercises(int workoutId, List<int> ids) async {
    await repository.reorderWorkoutExercises(workoutId, ids);
    await reloadActiveWorkout();
  }

  Future<void> updateWorkoutExercise(
    WorkoutExercise exercise, {
    int? supersetGroup,
    int? restSeconds,
    String? notes,
  }) async {
    await repository.updateWorkoutExercise(
      exercise,
      supersetGroup: supersetGroup,
      restSeconds: restSeconds,
      notes: notes,
    );
    await reloadActiveWorkout();
  }

  Future<PreviousPerformance?> previousPerformance(int exerciseId) async {
    return repository.previousPerformance(
      exerciseId,
      excludeWorkoutId: _activeWorkout?.id,
    );
  }

  Future<WorkoutFinishResult> finishActiveWorkout() async {
    final active = _activeWorkout;
    if (active == null) {
      throw const TrainingRepositoryException('No workout is active.');
    }
    final before = await repository.workouts();
    final finished = await repository.finishWorkout(active.id);
    _activeWorkout = null;
    _history = await repository.workouts();
    _records = await repository.personalRecords();
    final allExercises = await repository.exercises(includeArchived: true);
    final updates = newRecordsForWorkout(
      previousWorkouts: before,
      workout: finished,
      exercises: allExercises,
    );
    notifyListeners();
    return WorkoutFinishResult(workout: finished, newRecords: updates);
  }

  Future<void> discardActiveWorkout() async {
    final active = _activeWorkout;
    if (active == null) return;
    await repository.discardWorkout(active.id);
    _activeWorkout = null;
    notifyListeners();
  }

  Future<void> updateWorkoutDetails({
    required int id,
    required String name,
    required String notes,
  }) async {
    await repository.updateWorkoutDetails(id: id, name: name, notes: notes);
    _history = await repository.workouts();
    notifyListeners();
  }

  Future<void> deleteWorkout(int id) async {
    await repository.deleteWorkout(id);
    if (_activeWorkout?.id == id) _activeWorkout = null;
    _history = await repository.workouts();
    _records = await repository.personalRecords();
    notifyListeners();
  }

  Future<void> addBodyMetric(BodyMetric metric) async {
    await repository.addBodyMetric(metric);
    _bodyMetrics = await repository.bodyMetrics();
    notifyListeners();
  }

  Future<void> deleteBodyMetric(int id) async {
    await repository.deleteBodyMetric(id);
    _bodyMetrics = await repository.bodyMetrics();
    notifyListeners();
  }

  Future<void> addProgressPhoto(
    List<int> bytes, {
    DateTime? takenAt,
    String note = '',
  }) async {
    await repository.addProgressPhoto(
      Uint8List.fromList(bytes),
      takenAt: takenAt,
      note: note,
    );
    _photos = await repository.progressPhotos();
    notifyListeners();
  }

  Future<void> deleteProgressPhoto(int id) async {
    await repository.deleteProgressPhoto(id);
    _photos = await repository.progressPhotos();
    notifyListeners();
  }

  Future<String> exportJson() => repository.exportJson();

  Future<String> exportCsv() => repository.exportCsv();

  Future<void> importBackup(String json) async {
    await repository.importBackup(json);
    await refreshAll();
  }

  Future<void> resetLocalData() async {
    await repository.resetTrainingData();
    await refreshAll();
  }

  String _messageFor(Object error) {
    if (error is TrainingRepositoryException) return error.message;
    return 'Could not load the training log.';
  }
}
