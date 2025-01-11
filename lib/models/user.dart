import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  String uid; // Use Firebase UID
  String name;
  int age;
  double weight;
  double height;
  int weeklyGymTime;

  User({
    required this.uid,
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    this.weeklyGymTime = 0,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'age': age,
      'weight': weight,
      'height': height,
      'weeklyGymTime': weeklyGymTime,
    };
  }

  factory User.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return User(
      uid: doc.id,
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
      weight: data['weight'] ?? 0.0,
      height: data['height'] ?? 0.0,
      weeklyGymTime: data['weeklyGymTime'] ?? 0,
    );
  }
}