import 'package:cloud_firestore/cloud_firestore.dart';

class DietPlan {
  final String uid; // User ID
  final String dayOfWeek; // e.g., "Monday", "Tuesday"
  final String breakfast;
  final String lunch;
  final String dinner;
  final bool hasSnack;
  final String? snackDetails; // Nullable if hasSnack is false
  final bool isCheatDay;

  DietPlan({
    required this.uid,
    required this.dayOfWeek,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    this.hasSnack = false,
    this.snackDetails,
    this.isCheatDay = false,
  });

  // Factory constructor to create a DietPlan object from a Firestore document
  factory DietPlan.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('missing data for diet planId: ${snapshot.id}');
    }

    return DietPlan(
      uid: data['uid'] as String,
      dayOfWeek: data['dayOfWeek'] as String,
      breakfast: data['breakfast'] as String,
      lunch: data['lunch'] as String,
      dinner: data['dinner'] as String,
      hasSnack: data['hasSnack'] as bool? ?? false, // Default to false if null
      snackDetails: data['snackDetails'] as String?,
      isCheatDay: data['isCheatDay'] as bool? ?? false, // Default to false if null
    );
  }

  // Method to convert a DietPlan object into a Map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'dayOfWeek': dayOfWeek,
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
      'hasSnack': hasSnack,
      'snackDetails': snackDetails,
      'isCheatDay': isCheatDay,
    };
  }
}