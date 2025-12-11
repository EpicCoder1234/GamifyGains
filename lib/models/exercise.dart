// lib/models/exercise.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Exercise {
  final String id; // Unique ID (e.g., from UUID)
  final String name;
  final String? description; // New field
  final String category; // e.g., Chest, Legs, Cardio
  final List<String> targetMuscles; // Changed from String to List<String>
  final List<String>? equipment; // New field
  final String? difficulty; // New field
  final String? videoLink; // Optional link to a video demonstration

  Exercise({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.targetMuscles,
    this.equipment,
    this.difficulty,
    this.videoLink,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'targetMuscles': targetMuscles,
      'equipment': equipment,
      'difficulty': difficulty,
      'videoLink': videoLink,
    };
  }

  factory Exercise.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Firestore document data is null for exerciseId: ${snapshot.id}');
    }

    return Exercise(
      id: data['id'] as String? ?? snapshot.id,
      name: data['name'] as String? ?? 'Unnamed Exercise',
      description: data['description'] as String?,
      category: data['category'] as String? ?? 'Uncategorized',
      targetMuscles: List<String>.from(data['targetMuscles'] ?? []),
      equipment: (data['equipment'] as List?)?.map((e) => e as String).toList(),
      difficulty: data['difficulty'] as String?,
      videoLink: data['videoLink'] as String?,
    );
  }
}
