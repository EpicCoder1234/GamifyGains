// lib/models/workout.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart'; // Add for default timestamp generation

class Workout {
  final String id;
  final String uid;
  String name;
  int sets;
  int reps;
  double? weight;
  String date; // This field stores the specific date in 'yyyy-MM-dd' format
  String dayOfWeek; // NEW: Stores the day name (e.g., "Monday") for repeating schedule
  String type;
  String difficulty;
  String? notes;
  String timestamp; // ISO 8601 string of when the workout was recorded/modified
  String exerciseName; // Denormalized: Store exercise name for easier display/query
  String category; // Denormalized: Store exercise category for easier filtering/query
  String? exerciseId; // ID of the Exercise this Workout is based on

  Workout({
    required this.id,
    required this.uid,
    required this.name,
    required this.sets,
    required this.reps,
    this.weight,
    required this.date, // Specific date
    required this.dayOfWeek, // Day of the week name
    this.type = 'Weightlifting',
    required this.difficulty,
    this.notes,
    required this.timestamp,
    required this.exerciseName,
    required this.category,
    this.exerciseId,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'uid': uid,
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'date': date, // Specific date
      'dayOfWeek': dayOfWeek, // Day of week name
      'type': type,
      'difficulty': difficulty,
      'notes': notes,
      'timestamp': timestamp,
      'exerciseName': exerciseName,
      'category': category,
      'exerciseId': exerciseId,
    };
  }

  factory Workout.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Firestore document data is null for workoutId: ${snapshot.id}');
    }

    final String docId = data['id'] as String? ?? snapshot.id;
    final String retrievedUid = data['uid'] as String? ?? 'unknown_uid';
    final String retrievedName = data['name'] as String? ?? 'Unnamed Workout';
    final int retrievedSets = data['sets'] as int? ?? 0;
    final int retrievedReps = data['reps'] as int? ?? 0;
    final double? retrievedWeight = (data['weight'] as num?)?.toDouble();

    // Prioritize 'date', then 'day' (legacy), then current date
    final String retrievedDate = (data['date'] as String?) ??
                                 (data['day'] as String?) ?? // Check for legacy 'day' field
                                 DateFormat('yyyy-MM-dd').format(DateTime.now());

    // NEW: Handle 'dayOfWeek' retrieval. If missing, derive from 'date' or use 'Unknown'.
    final String retrievedDayOfWeek = (data['dayOfWeek'] as String?) ??
                                     DateFormat('EEEE').format(DateTime.parse(retrievedDate)); // Derive from date
                                     // Fallback to "Unknown" if date parsing also fails, though less likely with previous fallback
    
    final String retrievedType = data['type'] as String? ?? 'Weightlifting';
    final String retrievedDifficulty = data['difficulty'] as String? ?? 'Medium';
    final String? retrievedNotes = data['notes'] as String?;
    final String retrievedTimestamp = data['timestamp'] as String? ?? DateTime.now().toIso8601String();
    final String retrievedExerciseName = data['exerciseName'] as String? ?? retrievedName;
    final String retrievedCategory = data['category'] as String? ?? 'Uncategorized';
    final String? retrievedExerciseId = data['exerciseId'] as String?;

    return Workout(
      id: docId,
      uid: retrievedUid,
      name: retrievedName,
      sets: retrievedSets,
      reps: retrievedReps,
      weight: retrievedWeight,
      date: retrievedDate,
      dayOfWeek: retrievedDayOfWeek, // Pass the new field
      type: retrievedType,
      difficulty: retrievedDifficulty,
      notes: retrievedNotes,
      timestamp: retrievedTimestamp,
      exerciseName: retrievedExerciseName,
      category: retrievedCategory,
      exerciseId: retrievedExerciseId,
    );
  }
}
