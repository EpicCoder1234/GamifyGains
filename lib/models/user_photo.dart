// lib/models/user_photo.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserPhoto {
  final String id; // Document ID in Firestore
  final String uid; // User ID
  final String imageUrl; // URL to Firebase Storage image
  final Timestamp timestamp; // When the photo was uploaded

  UserPhoto({
    required this.id,
    required this.uid,
    required this.imageUrl,
    required this.timestamp,
  });

  // Factory constructor to create a UserPhoto from a Firestore DocumentSnapshot
  factory UserPhoto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserPhoto(
      id: doc.id,
      uid: data['uid'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }

  // Method to convert a UserPhoto object to a Firestore-compatible Map
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'imageUrl': imageUrl,
      'timestamp': timestamp,
    };
  }
}
