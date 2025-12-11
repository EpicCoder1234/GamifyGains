// lib/services/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/workout.dart';
import '../models/gym_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // NEW: Import Firebase Storage
import '../models/user.dart';
import '../models/diet_plan.dart';
import '../models/exercise.dart';
import '../models/user_photo.dart'; // NEW: Import UserPhoto model
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // NEW: For XFile type in upload

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const String databaseName = 'gamify_gains.db';
  static const int databaseVersion = 4;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // NEW: Firebase Storage instance

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
    // Your existing table creation logic might be missing here if it was done in a previous version.
    // For now, I'm just retaining the upgrade logic.
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print("Upgrading database from $oldVersion to $newVersion");
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE workouts ADD COLUMN day TEXT');
      } catch (e) {
        print("Error altering old workouts table (may not exist): $e");
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN weeklyGymTime INTEGER DEFAULT 0');
      } catch (e) {
        print("Error adding weeklyGymTime column to local users table: $e");
      }
    }
    if (oldVersion < 5) {
      // Future upgrade logic
      // If you plan to use SQLite for GymSession, you would create the table here.
      // Since your current approach seems to be Firestore-centric for GymSession,
      // I'll primarily focus on Firestore for the 'isCompleted' logic.
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

  // --- WORKOUT METHODS (Firestore-based) ---

  Future<void> saveWorkout(Workout workout) async {
    await _firestore
        .collection('users')
        .doc(workout.uid)
        .collection('workouts')
        .doc(workout.id)
        .set(workout.toFirestore(), SetOptions(merge: true));
    print('Workout ${workout.id} for user ${workout.uid} saved/updated in Firestore for ${workout.date} (${workout.dayOfWeek}).');
  }

  Stream<List<Workout>> getWorkoutsStream(String uid, String dayOfWeek) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('workouts')
        .where('dayOfWeek', isEqualTo: dayOfWeek)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Workout.fromFirestore(doc))
          .toList();
    });
  }

  Future<List<Workout>> getWorkoutsForDateRange(String uid, DateTime startDate, DateTime endDate) async {
    // Assuming 'date' in your Workout model is a String 'yyyy-MM-dd'
    // If it's a Timestamp, you'd use Timestamp.fromDate()
    String startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
    String endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

    final QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('workouts')
        .where('date', isGreaterThanOrEqualTo: startDateStr)
        .where('date', isLessThanOrEqualTo: endDateStr)
        .orderBy('date', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => Workout.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
  }


  Future<void> updateWorkout(Workout workout) async {
    await saveWorkout(workout);
    print('Workout ${workout.id} for user ${workout.uid} updated in Firestore.');
  }

  Future<void> deleteWorkout(String uid, String workoutId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('workouts')
        .doc(workoutId)
        .delete();
    print('Workout $workoutId for user $uid deleted from Firestore.');
  }

  // --- END WORKOUT METHODS ---


  // Saves a gym session for a specific user in Firestore, with daily limit check
  Future<void> saveGymSession(GymSession gymSession) async {
    // Check if a completed session already exists for today
    if (await hasCompletedGymSessionToday(gymSession.uid)) {
      throw Exception('A gym session has already been completed today.');
    }

    await _firestore
        .collection('users')
        .doc(gymSession.uid)
        .collection('gymSessions')
        .doc(gymSession.id)
        .set(gymSession.toFirestore(), SetOptions(merge: true));
    print('Gym Session ${gymSession.id} for user ${gymSession.uid} saved/updated in Firestore.');
  }

  // NEW: Method to update an existing gym session (e.g., set isCompleted to true)
  Future<void> updateGymSession(GymSession gymSession) async {
    await _firestore
        .collection('users')
        .doc(gymSession.uid)
        .collection('gymSessions')
        .doc(gymSession.id)
        .set(gymSession.toFirestore(), SetOptions(merge: true)); // Use set with merge to update
    print('Gym Session ${gymSession.id} for user ${gymSession.uid} updated in Firestore.');
  }


  // Retrieves gym sessions for a specific user within a date range from Firestore
  Future<List<GymSession>> getGymSessionsForDateRange(String uid, DateTime startDate, DateTime endDate) async {
    final QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('gymSessions')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)))) // Ensure end of day
        .orderBy('startTime', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => GymSession.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
  }

  // Retrieves all gym sessions for a specific user (no date filter)
  Future<List<GymSession>> getGymSessions(String uid) async {
    final QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('gymSessions')
        .orderBy('startTime', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => GymSession.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
  }


  // Deletes a specific gym session from Firestore
  Future<void> deleteGymSessionFirestore(String uid, String sessionId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('gymSessions')
        .doc(sessionId)
        .delete();
    print('Gym session $sessionId for user $uid deleted from Firestore.');
  }

  // NEW: Method to check if a completed gym session exists for the current day
  Stream<bool> hasCompletedGymSessionTodayStream(String uid) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('gymSessions')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfToday))
        .where('isCompleted', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  // Used for one-off checks (e.g., inside onPressed before navigation)
  Future<bool> hasCompletedGymSessionToday(String uid) async {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('gymSessions')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfToday))
          .where('isCompleted', isEqualTo: true)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
  }


  // --- USER METHODS (Firestore - Existing) ---
  Future<User?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return User.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      } else {
        return null;
      }
    } catch (e) {
      print("Error getting user from Firestore: $e");
      return null;
    }
  }

  Future<void> updateUser(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      print("Error updating user in Firestore: $e");
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

  // --- DIET PLAN METHODS (Firestore - Existing) ---

  Future<void> saveDietPlan(DietPlan dietPlan) async {
    await _firestore
        .collection('users')
        .doc(dietPlan.uid)
        .collection('dietPlans')
        .doc(dietPlan.dayOfWeek)
        .set(dietPlan.toFirestore(), SetOptions(merge: true));
    print('Diet plan for ${dietPlan.dayOfWeek} for user ${dietPlan.uid} saved/updated in Firestore.');
  }

  Future<DietPlan?> getDietPlan(String uid, String dayOfWeek) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('dietPlans')
          .doc(dayOfWeek)
          .get();

      if (doc.exists) {
        return DietPlan.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting diet plan for $dayOfWeek from Firestore: $e');
    }
    return null;
  }

  Stream<DietPlan?> getDietPlanStream(String uid, String dayOfWeek) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('dietPlans')
        .doc(dayOfWeek)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            return DietPlan.fromFirestore(snapshot);
          }
          return null;
        });
  }
    // --- EXERCISE METHODS (Firestore-based) ---

  Future<void> saveUserExercise(String uid, Exercise exercise) async {
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('user_exercises')
        .doc(exercise.id.isEmpty ? null : exercise.id);

    await docRef.set(exercise.toFirestore(), SetOptions(merge: true));
    print('User Exercise ${docRef.id} for user $uid saved/updated in Firestore.');
  }

  Stream<List<Exercise>> getUserExercisesStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('user_exercises')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Exercise.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
              .toList();
        });
  }

  Stream<List<Exercise>> getCommonExercisesStream([String? category, String? equipment]) {
    Query query = _firestore.collection('exercises');
    if (category != null && category.isNotEmpty && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }
    if (equipment != null && equipment.isNotEmpty && equipment != 'Any') {
        if (equipment == 'None') {
            query = query.where('equipment', arrayContains: 'None');
        } else {
            // This is problematic with multiple `arrayContains` or `arrayContainsAny`
            // If you need to filter by multiple equipment types, this will need
            // more complex logic (e.g., separate queries and merge, or client-side filter)
            // For now, assuming only one specific equipment filter, or 'None'.
             query = query.where('equipment', arrayContainsAny: [equipment]); // This will match any exercise that has *any* of the specified equipment.
        }
    }
    return query.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Exercise.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    });
  }


  Future<List<Exercise>> getFilteredExercises(List<String> categories, List<String> equipment) async {
    Query query = _firestore.collection('exercises');

    if (categories.isNotEmpty) {
      query = query.where('category', whereIn: categories);
    }

    if (equipment.isNotEmpty) {
        // For 'None' equipment, ensure it's explicitly in the list or field is empty
        if (equipment.contains('None')) {
            query = query.where('equipment', arrayContains: 'None');
        } else {
            // This is problematic with multiple `arrayContains` or `arrayContainsAny`
            // If you need to filter by multiple equipment types, this will need
            // more complex logic (e.g., separate queries and merge, or client-side filter)
            // For now, assuming only one specific equipment filter, or 'None'.
             query = query.where('equipment', arrayContainsAny: equipment); // This will match any exercise that has *any* of the specified equipment.
        }
    }

    final QuerySnapshot snapshot = await query.get();

    List<Exercise> exercises = snapshot.docs
        .map((doc) => Exercise.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();

    // Client-side filtering for genuinely empty equipment array if 'None' is meant to cover that too.
    if (equipment.contains('None')) {
      exercises = exercises.where((ex) => (ex.equipment?.contains('None') ?? false) || (ex.equipment?.isEmpty ?? false)).toList();
    }
    
    return exercises;
  }

  Future<Exercise?> getCommonExerciseById(String exerciseId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection('exercises')
          .doc(exerciseId)
          .get();

      if (doc.exists) {
        return Exercise.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting common exercise $exerciseId from Firestore: $e');
    }
    return null;
  }

  // --- NEW: GALLERY METHODS (Firebase Storage & Firestore) ---

  // Uploads an image to Firebase Storage and returns its download URL
  Future<String> uploadUserPhoto(String uid, XFile imageFile, String photoId) async {
    try {
      final String filePath = 'users/$uid/gallery/$photoId.jpg';
      final Reference storageRef = _storage.ref().child(filePath);

      // Convert XFile to Bytes for upload
      final bytes = await imageFile.readAsBytes();
      final UploadTask uploadTask = storageRef.putData(bytes);

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print('Image uploaded to Firebase Storage: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading image to Firebase Storage: $e');
      rethrow;
    }
  }

  // Saves photo metadata to Firestore
  Future<void> saveUserPhotoMetadata(UserPhoto photo) async {
    await _firestore
        .collection('users')
        .doc(photo.uid)
        .collection('photos')
        .doc(photo.id)
        .set(photo.toFirestore(), SetOptions(merge: true));
    print('Photo metadata ${photo.id} for user ${photo.uid} saved/updated in Firestore.');
  }

  // Retrieves a stream of all user photos, ordered by timestamp (most recent first)
  Stream<List<UserPhoto>> getUserPhotosStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('photos')
        .orderBy('timestamp', descending: true) // Most recent first
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserPhoto.fromFirestore(doc))
          .toList();
    });
  }

  // Fetches the single latest user photo for the home screen widget
  Future<UserPhoto?> getLatestUserPhoto(String uid) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('photos')
          .orderBy('timestamp', descending: true)
          .limit(1) // Get only the latest one
          .get();

      if (snapshot.docs.isNotEmpty) {
        return UserPhoto.fromFirestore(snapshot.docs.first as DocumentSnapshot<Map<String, dynamic>>);
      }
      return null;
    } catch (e) {
      print('Error fetching latest user photo: $e');
      return null;
    }
  }

  // Deletes a photo from Firebase Storage and its metadata from Firestore
  Future<void> deleteUserPhoto(String uid, String photoId, String imageUrl) async {
    try {
      // Delete from Firebase Storage
      await _storage.refFromURL(imageUrl).delete();
      print('Photo deleted from Storage: $imageUrl');

      // Delete metadata from Firestore
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('photos')
          .doc(photoId)
          .delete();
      print('Photo metadata $photoId deleted from Firestore.');
    } catch (e) {
      print('Error deleting photo: $e');
      rethrow;
    }
  }
}