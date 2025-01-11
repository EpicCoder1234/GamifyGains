import 'workout.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart'; // Import sqflite

class GymSession {
  final String id;
  DateTime date;
  List<Workout> workouts;
  Duration? duration;

  GymSession({
    required this.date,
    required this.workouts,
    this.duration,
  }) : id = const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch, // Store as milliseconds
      'duration': duration?.inMilliseconds,
    };
  }

  static GymSession fromMap(Map<String, dynamic> map) {
    return GymSession(
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      workouts: [], // Workouts will be fetched separately
      duration: map['duration'] != null ? Duration(milliseconds: map['duration']) : null,
    );
  }
}