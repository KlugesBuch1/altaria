import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class TrainingDatabase {
  TrainingDatabase._(this.db);

  static const int schemaVersion = 1;
  static const String databaseName = 'altaria_training.db';

  final Database db;

  static Future<TrainingDatabase> open({String? databasePath}) async {
    final target =
        databasePath ?? path.join(await getDatabasesPath(), databaseName);
    final db = await openDatabase(
      target,
      version: schemaVersion,
      onConfigure: _configure,
      onCreate: (db, version) => _migrate(db, 1, version),
      onUpgrade: (db, oldVersion, newVersion) =>
          _migrate(db, oldVersion + 1, newVersion),
    );
    return TrainingDatabase._(db);
  }

  static Future<TrainingDatabase> openWithFactory(
    DatabaseFactory factory, {
    String databasePath = ':memory:',
    bool singleInstance = false,
  }) async {
    final db = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        singleInstance: singleInstance,
        onConfigure: _configure,
        onCreate: (db, version) => _migrate(db, 1, version),
        onUpgrade: (db, oldVersion, newVersion) =>
            _migrate(db, oldVersion + 1, newVersion),
      ),
    );
    return TrainingDatabase._(db);
  }

  Future<void> close() => db.close();

  static Future<void> _configure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _migrate(
    DatabaseExecutor db,
    int fromVersion,
    int toVersion,
  ) async {
    for (var version = fromVersion; version <= toVersion; version++) {
      if (version == 1) {
        await _createVersion1(db);
      } else {
        throw StateError('No migration for schema version $version');
      }
      await db.insert('schema_migrations', {
        'version': version,
        'applied_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  static Future<void> _createVersion1(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE schema_migrations (
        version INTEGER PRIMARY KEY,
        applied_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE,
        muscle_group TEXT NOT NULL,
        equipment TEXT NOT NULL,
        cues TEXT NOT NULL DEFAULT '',
        is_custom INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX exercises_name_unique ON exercises(name COLLATE NOCASE)',
    );
    await db.execute('''
      CREATE TABLE routines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE routine_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER NOT NULL
          REFERENCES routines(id) ON DELETE CASCADE,
        exercise_id INTEGER NOT NULL
          REFERENCES exercises(id) ON DELETE RESTRICT,
        position INTEGER NOT NULL,
        superset_group INTEGER NOT NULL DEFAULT 0,
        target_sets INTEGER NOT NULL DEFAULT 3,
        target_reps INTEGER NOT NULL DEFAULT 8,
        target_weight_kg REAL,
        rest_seconds INTEGER NOT NULL DEFAULT 90,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute(
      'CREATE INDEX routine_exercises_routine ON routine_exercises(routine_id)',
    );
    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        finished_at INTEGER,
        status TEXT NOT NULL DEFAULT 'active',
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        total_volume_kg REAL NOT NULL DEFAULT 0,
        set_count INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        routine_id INTEGER REFERENCES routines(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX workouts_status ON workouts(status, started_at)',
    );
    await db.execute('CREATE INDEX workouts_finished ON workouts(finished_at)');
    await db.execute('''
      CREATE TABLE workout_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL
          REFERENCES workouts(id) ON DELETE CASCADE,
        exercise_id INTEGER NOT NULL
          REFERENCES exercises(id) ON DELETE RESTRICT,
        position INTEGER NOT NULL,
        superset_group INTEGER NOT NULL DEFAULT 0,
        rest_seconds INTEGER NOT NULL DEFAULT 90,
        notes TEXT NOT NULL DEFAULT '',
        target_sets INTEGER NOT NULL DEFAULT 0,
        target_reps INTEGER NOT NULL DEFAULT 0,
        target_weight_kg REAL
      )
    ''');
    await db.execute(
      'CREATE INDEX workout_exercises_workout ON workout_exercises(workout_id)',
    );
    await db.execute('''
      CREATE TABLE workout_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_exercise_id INTEGER NOT NULL
          REFERENCES workout_exercises(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        kind TEXT NOT NULL DEFAULT 'normal',
        weight_kg REAL NOT NULL DEFAULT 0,
        reps INTEGER NOT NULL DEFAULT 0,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        distance_meters REAL NOT NULL DEFAULT 0,
        rpe REAL,
        completed INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute(
      'CREATE INDEX workout_sets_exercise ON workout_sets(workout_exercise_id)',
    );
    await db.execute('''
      CREATE TABLE body_metrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        measured_at INTEGER NOT NULL,
        weight_kg REAL,
        body_fat REAL,
        chest_cm REAL,
        waist_cm REAL,
        hips_cm REAL,
        arm_cm REAL,
        thigh_cm REAL,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE progress_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taken_at INTEGER NOT NULL,
        bytes BLOB NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }
}
