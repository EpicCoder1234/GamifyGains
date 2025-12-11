// lib/models/gym_session.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // Import for Timestamp

class GymSession {
  final String id;
  final String uid; // Added: To link session to a specific user
  final DateTime startTime; // Changed: Using DateTime for precise timing and querying
  final int duration; // Duration in seconds
  final bool isCompleted; // Added: To track if the session is completed

  GymSession({
    required this.id,
    required this.uid,
    required this.startTime,
    required this.duration,
    this.isCompleted = false, // Default to false
  });

  // Method to convert GymSession object to a Firestore-compatible Map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'uid': uid,
      'startTime': Timestamp.fromDate(startTime), // Convert DateTime to Firestore Timestamp
      'duration': duration,
      'isCompleted': isCompleted, // Include isCompleted
    };
  }

  // Factory method to create a GymSession object from a Firestore DocumentSnapshot
  factory GymSession.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!; // Get the data map from the document
    return GymSession(
      id: doc.id, // Use doc.id for the ID
      uid: data['uid'] as String,
      startTime: (data['startTime'] as Timestamp).toDate(), // Convert Timestamp back to DateTime
      duration: data['duration'] as int,
      isCompleted: data['isCompleted'] as bool? ?? false, // Retrieve isCompleted, default to false if null
    );
  }

  // Optional: A method to create GymSession from a standard Map (if you still need it, e.g., for local in-memory processing)
  // But generally, for Firestore-based models, `fromFirestore` is preferred.
  factory GymSession.fromMap(Map<String, dynamic> map) {
    return GymSession(
      id: map['id'] as String,
      uid: map['uid'] as String,
      startTime: map['startTime'] is Timestamp
          ? (map['startTime'] as Timestamp).toDate()
          : DateTime.parse(map['startTime'] as String), // Handle both Timestamp and String for backward compatibility during migration if needed
      duration: map['duration'] as int,
      isCompleted: map['isCompleted'] as bool? ?? false, // Retrieve isCompleted, default to false if null
    );
  }

  // Method to create a copy of GymSession with updated fields (useful for immutability)
  GymSession copyWith({
    String? id,
    String? uid,
    DateTime? startTime,
    int? duration,
    bool? isCompleted,
  }) {
    return GymSession(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}