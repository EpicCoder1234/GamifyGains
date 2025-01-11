import 'package:uuid/uuid.dart';

class Workout {
  final String id;
  String name;
  int sets;
  int reps;
  double? weight;
  String day;

  Workout({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    this.weight,
    required this.day,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'day': day,
    };
  }

  static Workout fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'],
      name: map['name'],
      sets: map['sets'],
      reps: map['reps'],
      weight: map['weight']?.toDouble(),
      day: map['day'],
    );
  }
}