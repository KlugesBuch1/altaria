import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

enum AppMode {
  listen,
  train;

  static AppMode parse(Object? value) =>
      value == train.storage ? train : listen;

  String get storage => name;
}

enum WeightUnit {
  kg,
  lb;

  static WeightUnit parse(Object? value) => value == lb.storage ? lb : kg;

  String get storage => name;
}

enum SetKind {
  normal,
  warmup,
  drop,
  failure;

  static SetKind parse(Object? value) {
    for (final kind in values) {
      if (kind.storage == value) return kind;
    }
    return normal;
  }

  String get storage => name;

  String get label => switch (this) {
    normal => 'Working',
    warmup => 'Warm-up',
    drop => 'Drop',
    failure => 'Failure',
  };
}

enum MuscleGroup {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  quads,
  hamstrings,
  glutes,
  calves,
  core,
  fullBody,
  conditioning;

  static MuscleGroup parse(Object? value) {
    for (final group in values) {
      if (group.storage == value) return group;
    }
    return fullBody;
  }

  String get storage => name;

  String get label => switch (this) {
    chest => 'Chest',
    back => 'Back',
    shoulders => 'Shoulders',
    biceps => 'Biceps',
    triceps => 'Triceps',
    quads => 'Quads',
    hamstrings => 'Hamstrings',
    glutes => 'Glutes',
    calves => 'Calves',
    core => 'Core',
    fullBody => 'Full body',
    conditioning => 'Conditioning',
  };
}

enum Equipment {
  barbell,
  dumbbell,
  machine,
  cable,
  bodyweight,
  kettlebell,
  band,
  cardio,
  other;

  static Equipment parse(Object? value) {
    for (final equipment in values) {
      if (equipment.storage == value) return equipment;
    }
    return other;
  }

  String get storage => name;

  String get label => switch (this) {
    barbell => 'Barbell',
    dumbbell => 'Dumbbell',
    machine => 'Machine',
    cable => 'Cable',
    bodyweight => 'Bodyweight',
    kettlebell => 'Kettlebell',
    band => 'Band',
    cardio => 'Cardio',
    other => 'Other',
  };
}

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    this.cues = '',
    this.custom = false,
    this.archived = false,
  });

  final int id;
  final String name;
  final MuscleGroup muscleGroup;
  final Equipment equipment;
  final String cues;
  final bool custom;
  final bool archived;

  Exercise copyWith({
    int? id,
    String? name,
    MuscleGroup? muscleGroup,
    Equipment? equipment,
    String? cues,
    bool? custom,
    bool? archived,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      cues: cues ?? this.cues,
      custom: custom ?? this.custom,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup.storage,
    'equipment': equipment.storage,
    'cues': cues,
    'custom': custom,
    'archived': archived,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      muscleGroup: MuscleGroup.parse(json['muscleGroup']),
      equipment: Equipment.parse(json['equipment']),
      cues: (json['cues'] as String?) ?? '',
      custom: json['custom'] == true,
      archived: json['archived'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Exercise &&
      other.id == id &&
      other.name == name &&
      other.muscleGroup == muscleGroup &&
      other.equipment == equipment &&
      other.cues == cues &&
      other.custom == custom &&
      other.archived == archived;

  @override
  int get hashCode =>
      Object.hash(id, name, muscleGroup, equipment, cues, custom, archived);
}

class RoutineExercise {
  const RoutineExercise({
    required this.id,
    required this.exercise,
    required this.position,
    this.supersetGroup = 0,
    this.targetSets = 3,
    this.targetReps = 8,
    this.targetWeightKg,
    this.restSeconds = 90,
    this.notes = '',
  });

  final int id;
  final Exercise exercise;
  final int position;
  final int supersetGroup;
  final int targetSets;
  final int targetReps;
  final double? targetWeightKg;
  final int restSeconds;
  final String notes;

  int get exerciseId => exercise.id;

  RoutineExercise copyWith({
    int? id,
    Exercise? exercise,
    int? position,
    int? supersetGroup,
    int? targetSets,
    int? targetReps,
    Object? targetWeightKg = _unset,
    int? restSeconds,
    String? notes,
  }) {
    return RoutineExercise(
      id: id ?? this.id,
      exercise: exercise ?? this.exercise,
      position: position ?? this.position,
      supersetGroup: supersetGroup ?? this.supersetGroup,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      targetWeightKg: identical(targetWeightKg, _unset)
          ? this.targetWeightKg
          : targetWeightKg as double?,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'position': position,
    'supersetGroup': supersetGroup,
    'targetSets': targetSets,
    'targetReps': targetReps,
    'targetWeightKg': targetWeightKg,
    'restSeconds': restSeconds,
    'notes': notes,
  };
}

class Routine {
  const Routine({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.exercises = const [],
  });

  final int id;
  final String name;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RoutineExercise> exercises;

  Routine copyWith({
    int? id,
    String? name,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<RoutineExercise>? exercises,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      exercises: exercises ?? this.exercises,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
  };
}

class WorkoutSet {
  const WorkoutSet({
    required this.id,
    required this.position,
    required this.kind,
    this.weightKg = 0,
    this.reps = 0,
    this.durationSeconds = 0,
    this.distanceMeters = 0,
    this.rpe,
    this.completed = false,
    this.notes = '',
  });

  final int id;
  final int position;
  final SetKind kind;
  final double weightKg;
  final int reps;
  final int durationSeconds;
  final double distanceMeters;
  final double? rpe;
  final bool completed;
  final String notes;

  bool get isWarmup => kind == SetKind.warmup;

  double get volumeKg => completed && !isWarmup ? weightKg * reps : 0;

  WorkoutSet copyWith({
    int? id,
    int? position,
    SetKind? kind,
    double? weightKg,
    int? reps,
    int? durationSeconds,
    double? distanceMeters,
    Object? rpe = _unset,
    bool? completed,
    String? notes,
  }) {
    return WorkoutSet(
      id: id ?? this.id,
      position: position ?? this.position,
      kind: kind ?? this.kind,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      rpe: identical(rpe, _unset) ? this.rpe : rpe as double?,
      completed: completed ?? this.completed,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': position,
    'kind': kind.storage,
    'weightKg': weightKg,
    'reps': reps,
    'durationSeconds': durationSeconds,
    'distanceMeters': distanceMeters,
    'rpe': rpe,
    'completed': completed,
    'notes': notes,
  };

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      id: (json['id'] as num?)?.toInt() ?? 0,
      position: (json['position'] as num?)?.toInt() ?? 0,
      kind: SetKind.parse(json['kind']),
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      rpe: (json['rpe'] as num?)?.toDouble(),
      completed: json['completed'] == true,
      notes: (json['notes'] as String?) ?? '',
    );
  }
}

class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.exercise,
    required this.position,
    this.supersetGroup = 0,
    this.restSeconds = 90,
    this.notes = '',
    this.targetSets = 0,
    this.targetReps = 0,
    this.targetWeightKg,
    this.sets = const [],
  });

  final int id;
  final Exercise exercise;
  final int position;
  final int supersetGroup;
  final int restSeconds;
  final String notes;
  final int targetSets;
  final int targetReps;
  final double? targetWeightKg;
  final List<WorkoutSet> sets;

  int get exerciseId => exercise.id;

  int get completedSets => sets.where((set) => set.completed).length;

  double get volumeKg =>
      sets.fold<double>(0, (total, set) => total + set.volumeKg);

  WorkoutSet? get lastCompletedSet {
    for (final set in sets.reversed) {
      if (set.completed) return set;
    }
    return null;
  }

  WorkoutExercise copyWith({
    int? id,
    Exercise? exercise,
    int? position,
    int? supersetGroup,
    int? restSeconds,
    String? notes,
    int? targetSets,
    int? targetReps,
    Object? targetWeightKg = _unset,
    List<WorkoutSet>? sets,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      exercise: exercise ?? this.exercise,
      position: position ?? this.position,
      supersetGroup: supersetGroup ?? this.supersetGroup,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      targetWeightKg: identical(targetWeightKg, _unset)
          ? this.targetWeightKg
          : targetWeightKg as double?,
      sets: sets ?? this.sets,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'position': position,
    'supersetGroup': supersetGroup,
    'restSeconds': restSeconds,
    'notes': notes,
    'targetSets': targetSets,
    'targetReps': targetReps,
    'targetWeightKg': targetWeightKg,
    'sets': sets.map((set) => set.toJson()).toList(),
  };
}

class Workout {
  const Workout({
    required this.id,
    required this.name,
    required this.startedAt,
    this.finishedAt,
    this.status = 'active',
    this.durationSeconds = 0,
    this.totalVolumeKg = 0,
    this.setCount = 0,
    this.notes = '',
    this.routineId,
    this.exercises = const [],
  });

  final int id;
  final String name;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String status;
  final int durationSeconds;
  final double totalVolumeKg;
  final int setCount;
  final String notes;
  final int? routineId;
  final List<WorkoutExercise> exercises;

  bool get isFinished => status == 'finished';

  int get completedSetCount => exercises.fold<int>(
    0,
    (total, exercise) => total + exercise.completedSets,
  );

  Workout copyWith({
    int? id,
    String? name,
    DateTime? startedAt,
    Object? finishedAt = _unset,
    String? status,
    int? durationSeconds,
    double? totalVolumeKg,
    int? setCount,
    String? notes,
    Object? routineId = _unset,
    List<WorkoutExercise>? exercises,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: identical(finishedAt, _unset)
          ? this.finishedAt
          : finishedAt as DateTime?,
      status: status ?? this.status,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      totalVolumeKg: totalVolumeKg ?? this.totalVolumeKg,
      setCount: setCount ?? this.setCount,
      notes: notes ?? this.notes,
      routineId: identical(routineId, _unset)
          ? this.routineId
          : routineId as int?,
      exercises: exercises ?? this.exercises,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'status': status,
    'durationSeconds': durationSeconds,
    'totalVolumeKg': totalVolumeKg,
    'setCount': setCount,
    'notes': notes,
    'routineId': routineId,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
  };
}

class BodyMetric {
  const BodyMetric({
    required this.id,
    required this.measuredAt,
    this.weightKg,
    this.bodyFat,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.armCm,
    this.thighCm,
    this.notes = '',
  });

  final int id;
  final DateTime measuredAt;
  final double? weightKg;
  final double? bodyFat;
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;
  final double? armCm;
  final double? thighCm;
  final String notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'measuredAt': measuredAt.toIso8601String(),
    'weightKg': weightKg,
    'bodyFat': bodyFat,
    'chestCm': chestCm,
    'waistCm': waistCm,
    'hipsCm': hipsCm,
    'armCm': armCm,
    'thighCm': thighCm,
    'notes': notes,
  };

  factory BodyMetric.fromJson(Map<String, dynamic> json) {
    return BodyMetric(
      id: (json['id'] as num?)?.toInt() ?? 0,
      measuredAt:
          DateTime.tryParse(json['measuredAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      bodyFat: (json['bodyFat'] as num?)?.toDouble(),
      chestCm: (json['chestCm'] as num?)?.toDouble(),
      waistCm: (json['waistCm'] as num?)?.toDouble(),
      hipsCm: (json['hipsCm'] as num?)?.toDouble(),
      armCm: (json['armCm'] as num?)?.toDouble(),
      thighCm: (json['thighCm'] as num?)?.toDouble(),
      notes: (json['notes'] as String?) ?? '',
    );
  }
}

class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.takenAt,
    required this.bytes,
    this.note = '',
  });

  final int id;
  final DateTime takenAt;
  final Uint8List bytes;
  final String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'takenAt': takenAt.toIso8601String(),
    'bytes': base64Encode(bytes),
    'note': note,
  };

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) {
    final encoded = json['bytes'];
    return ProgressPhoto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      takenAt:
          DateTime.tryParse(json['takenAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      bytes: encoded is String ? base64Decode(encoded) : Uint8List(0),
      note: (json['note'] as String?) ?? '',
    );
  }
}

class PrEntry {
  const PrEntry({
    required this.value,
    required this.weightKg,
    required this.reps,
    required this.achievedAt,
    required this.workoutId,
  });

  final double value;
  final double weightKg;
  final int reps;
  final DateTime achievedAt;
  final int workoutId;
}

class RepAtWeight {
  const RepAtWeight({
    required this.weightKg,
    required this.reps,
    required this.achievedAt,
    required this.workoutId,
  });

  final double weightKg;
  final int reps;
  final DateTime achievedAt;
  final int workoutId;
}

class ExerciseRecords {
  const ExerciseRecords({
    required this.exercise,
    this.maxWeight,
    this.estimatedOneRepMax,
    this.setVolume,
    this.repsAtWeight = const [],
    this.workoutCount = 0,
  });

  final Exercise exercise;
  final PrEntry? maxWeight;
  final PrEntry? estimatedOneRepMax;
  final PrEntry? setVolume;
  final List<RepAtWeight> repsAtWeight;
  final int workoutCount;

  bool get hasSets => maxWeight != null;
}

class PersonalRecordUpdate {
  const PersonalRecordUpdate({
    required this.exercise,
    required this.label,
    required this.value,
  });

  final Exercise exercise;
  final String label;
  final double value;
}

class PreviousPerformance {
  const PreviousPerformance({
    required this.workout,
    required this.sets,
    required this.exercise,
  });

  final Workout workout;
  final List<WorkoutSet> sets;
  final Exercise exercise;
}

class TrainingSettings {
  const TrainingSettings({
    this.unit = WeightUnit.kg,
    this.defaultRestSeconds = 90,
    this.barWeightKg = 20,
    this.plateInventoryKg = const [25, 20, 15, 10, 5, 2.5, 1.25],
    this.barWeightLb = 45,
    this.plateInventoryLb = const [45, 35, 25, 10, 5, 2.5],
    this.keepAwake = true,
    this.restNotifications = true,
    this.lastMode = AppMode.listen,
  });

  final WeightUnit unit;
  final int defaultRestSeconds;
  final double barWeightKg;
  final List<double> plateInventoryKg;
  final double barWeightLb;
  final List<double> plateInventoryLb;
  final bool keepAwake;
  final bool restNotifications;
  final AppMode lastMode;

  double get barWeight => unit == WeightUnit.kg ? barWeightKg : barWeightLb;

  List<double> get plateInventory =>
      unit == WeightUnit.kg ? plateInventoryKg : plateInventoryLb;

  TrainingSettings copyWith({
    WeightUnit? unit,
    int? defaultRestSeconds,
    double? barWeightKg,
    List<double>? plateInventoryKg,
    double? barWeightLb,
    List<double>? plateInventoryLb,
    bool? keepAwake,
    bool? restNotifications,
    AppMode? lastMode,
  }) {
    return TrainingSettings(
      unit: unit ?? this.unit,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      barWeightKg: barWeightKg ?? this.barWeightKg,
      plateInventoryKg: plateInventoryKg ?? this.plateInventoryKg,
      barWeightLb: barWeightLb ?? this.barWeightLb,
      plateInventoryLb: plateInventoryLb ?? this.plateInventoryLb,
      keepAwake: keepAwake ?? this.keepAwake,
      restNotifications: restNotifications ?? this.restNotifications,
      lastMode: lastMode ?? this.lastMode,
    );
  }

  TrainingSettings withUnit(WeightUnit newUnit) => copyWith(unit: newUnit);

  TrainingSettings withBarWeight(double value) => unit == WeightUnit.kg
      ? copyWith(barWeightKg: value)
      : copyWith(barWeightLb: value);

  TrainingSettings withPlates(List<double> plates) => unit == WeightUnit.kg
      ? copyWith(plateInventoryKg: plates)
      : copyWith(plateInventoryLb: plates);

  Map<String, dynamic> toJson() => {
    'unit': unit.storage,
    'defaultRestSeconds': defaultRestSeconds,
    'barWeightKg': barWeightKg,
    'plateInventoryKg': plateInventoryKg,
    'barWeightLb': barWeightLb,
    'plateInventoryLb': plateInventoryLb,
    'keepAwake': keepAwake,
    'restNotifications': restNotifications,
    'lastMode': lastMode.storage,
  };

  factory TrainingSettings.fromJson(Map<String, dynamic> json) {
    const fallback = TrainingSettings();
    return TrainingSettings(
      unit: WeightUnit.parse(json['unit']),
      defaultRestSeconds:
          (json['defaultRestSeconds'] as num?)?.toInt() ??
          fallback.defaultRestSeconds,
      barWeightKg:
          (json['barWeightKg'] as num?)?.toDouble() ?? fallback.barWeightKg,
      plateInventoryKg: _doubleList(
        json['plateInventoryKg'],
        fallback.plateInventoryKg,
      ),
      barWeightLb:
          (json['barWeightLb'] as num?)?.toDouble() ?? fallback.barWeightLb,
      plateInventoryLb: _doubleList(
        json['plateInventoryLb'],
        fallback.plateInventoryLb,
      ),
      keepAwake: json['keepAwake'] is bool
          ? json['keepAwake'] as bool
          : fallback.keepAwake,
      restNotifications: json['restNotifications'] is bool
          ? json['restNotifications'] as bool
          : fallback.restNotifications,
      lastMode: AppMode.parse(json['lastMode']),
    );
  }

  static List<double> _doubleList(Object? value, List<double> fallback) {
    if (value is! List) return fallback;
    final output = value
        .whereType<num>()
        .map((item) => item.toDouble())
        .toList();
    output.sort((a, b) => b.compareTo(a));
    return List<double>.unmodifiable(output);
  }
}

const Object _unset = Object();

double clampDouble(double value, double min, double max) =>
    math.min(math.max(value, min), max);
