import 'package:uuid/uuid.dart';

class DietPlan {
  final String id;
  final String day;
  String plan; // The actual diet plan text

  DietPlan({
    required this.id,
    required this.day,
    required this.plan,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'day': day,
      'plan': plan,
    };
  }

  static DietPlan fromMap(Map<String, dynamic> map) {
    return DietPlan(
      id: map['id'],
      day: map['day'],
      plan: map['plan'],
    );
  }
}