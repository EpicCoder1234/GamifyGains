import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart'; // Import for Timer
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_helper.dart';
import '../models/user.dart'; // Assuming you have a User model

@pragma('vm:entry-point')
Future<bool> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final dbHelper = DatabaseHelper();
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    print("No user logged in");
    return false;
  }

  // Timer logic (using Timer from 'package:flutter/material.dart')
  Timer? timer;
  DateTime? startTime;

  service.on('startTimer').listen((event) {
    startTime ??= DateTime.now();
    print("Timer started at: $startTime"); // And this

    if (timer == null || !timer!.isActive) {
      print("Timer initialized");
      timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (startTime != null) {
          DateTime now = DateTime.now();
          final duration = now.difference(startTime!);
          String formattedTime = DateFormat('HH:mm:ss').format(DateTime(0).add(duration));

          if (service is AndroidServiceInstance && await service.isForegroundService()) {
            service.setForegroundNotificationInfo(
              title: "Workout in Progress",
              content: "Elapsed Time: $formattedTime",
            );
          }
          service.invoke("update", {"current_time": formattedTime});
        }
      });
    }
  });

  service.on('stopService').listen((event) async {
    if (timer != null && timer!.isActive) {
      timer!.cancel();
    }

    final endTime = DateTime.now();
    if (startTime != null) {
      final duration = endTime.difference(startTime!);
      final timerSeconds = duration.inSeconds;
      print("Workout Duration: $timerSeconds seconds");

      // Update Firebase
      final currentUser = await dbHelper.getUser(user.uid);
      if (currentUser != null) {
        currentUser.weeklyGymTime += timerSeconds;
        print("Updating Firebase with weeklyGymTime: ${currentUser.weeklyGymTime}");
        await dbHelper.updateUser(currentUser);
        print("Updated user's weekly gym time in Firebase");
      } else {
        print("Could not retrieve user from Firebase");
      }
    }

    service.stopSelf();
  });

  return true;
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // Set to false for manual start
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false, // Set to false for manual start
      onForeground: onStart,
      onBackground: null,
    ),
  );
}