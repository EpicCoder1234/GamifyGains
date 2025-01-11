import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/workout.dart';
import '../models/gym_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/diet_plan.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const String databaseName = 'gamify_gains.db';
  static const int databaseVersion = 4;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, databaseName);
    print('Database path: $path');

    try {
      return await openDatabase(path,
          onCreate: _onCreate, onUpgrade: _onUpgrade, version: databaseVersion);
    } catch (e) {
      print('Error opening database: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    print("Creating new database (version $version)");
    await db.execute('''
      CREATE TABLE workouts(
        id TEXT PRIMARY KEY,
        name TEXT,
        sets INTEGER,
        reps INTEGER,
        weight REAL,
        day TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE gym_sessions(
        id TEXT PRIMARY KEY,
        date TEXT,
        duration INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE users(
        id TEXT PRIMARY KEY,
        name TEXT,
        age INTEGER,
        weight REAL,
        height REAL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print("Upgrading database from $oldVersion to $newVersion");
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE workouts ADD COLUMN day TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE diet_plans(
          id TEXT PRIMARY KEY,
          day TEXT,
          plan TEXT
        )
      ''');
    }
      if (oldVersion < 4) { // Assuming this is version 4
    try {
      await db.execute('ALTER TABLE users ADD COLUMN weeklyGymTime INTEGER DEFAULT 0');
    } catch (e) {
      print("Error adding weeklyGymTime column: $e"); // Handle potential errors
    }
  }
    if (oldVersion < 5) {
      // Future upgrade logic
    }
  }

  Future<int> getCurrentDatabaseVersion() async {
    final db = await database;
    try {
      return await db.getVersion();
    } catch (e) {
      print("Error getting database version: $e");
      return 0;
    }
  }

  // CRUD operations
  Future<int> insertDietPlan(DietPlan dietPlan) async {
    final db = await database;
    return await db.insert('diet_plans', dietPlan.toMap());
  }

  Future<List<DietPlan>> getDietPlans(String day) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'diet_plans',
      where: 'day = ?',
      whereArgs: [day],
    );
    return List.generate(maps.length, (i) => DietPlan.fromMap(maps[i]));
  }

  Future<int> updateDietPlan(DietPlan dietPlan) async {
    final db = await database;
    return await db.update('diet_plans', dietPlan.toMap(), where: 'id = ?', whereArgs: [dietPlan.id]);
  }

  Future<int> deleteDietPlan(String id) async {
    final db = await database;
    return await db.delete('diet_plans', where: 'id = ?', whereArgs: [id]);
  }



  Future<int> insertWorkout(Workout workout) async {
    final db = await database;
    return await db.insert('workouts', workout.toMap());
  }

  Future<List<Workout>> getWorkouts(String day) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'workouts',
      where: 'day = ?',
      whereArgs: [day],
    );
    return List.generate(maps.length, (i) => Workout.fromMap(maps[i]));
  }

  Future<int> updateWorkout(Workout workout) async {
    final db = await database;
    return await db.update('workouts', workout.toMap(), where: 'id = ?', whereArgs: [workout.id]);
  }

  Future<int> deleteWorkout(String id) async {
    final db = await database;
    return await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

// Gym Session CRUD operations
    Future<int> insertGymSession(GymSession gymSession) async {
    final db = await database;
    return await db.insert('gym_sessions', gymSession.toMap());
  }

  Future<List<GymSession>> getGymSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('gym_sessions');
    return List.generate(maps.length, (i) {
      return GymSession.fromMap(maps[i]);
    });
  }

  Future<int> updateGymSession(GymSession gymSession) async {
    final db = await database;
    return await db.update('gym_sessions', gymSession.toMap(), where: 'id = ?', whereArgs: [gymSession.id]);
  }

Future<int> deleteGymSession(String id) async {
    final db = await database;
    return await db.delete('gym_sessions', where: 'id = ?', whereArgs: [id]);
  }

// User CRUD operations
   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return User.fromFirestore(doc);
      } else {
        return null;
      }
    } catch (e) {
      print("Error getting user: $e");
      return null;
    }
  }

  Future<void> updateUser(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      print("Error updating user: $e");
    }
  }

    Stream<List<User>> getUsersStream() {
    return _firestore.collection('users')
        .orderBy('weeklyGymTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => User.fromFirestore(doc)).toList();
    });
  }

}