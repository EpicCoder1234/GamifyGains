import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'database_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Top-level onStart function
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('startTimer').listen((event) {
    WorkoutService().startTimer();
  });

  service.on('stopService').listen((event) {
    WorkoutService().stopTimer();
    service.stopSelf();
  });
}

class WorkoutService {
  static final WorkoutService _instance = WorkoutService._internal();
  factory WorkoutService() => _instance;
  WorkoutService._internal();

  final service = FlutterBackgroundService();
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;

  Future<void> initializeService() async {
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart, // Use the top-level function
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'gamify_gains_timer',
        foregroundServiceNotificationId: 1,
        initialNotificationTitle: 'Workout Timer',
        initialNotificationContent: 'Timer is running in the background',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart, // Use the top-level function
        onBackground: null,
      ),
    );
  }

  void startTimer() {
    if (_isRunning) return;

    _isRunning = true;
    _elapsedSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      final timeStr = _formatTime(_elapsedSeconds);
      service.invoke('update', {'current_time': timeStr});
    });
  }

  void stopTimer() async {
    _timer?.cancel();
    _isRunning = false;

    // Save the elapsed time to the database
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final dbHelper = DatabaseHelper();
      final currentUserData = await dbHelper.getUser(user.uid);
      if (currentUserData != null) {
        currentUserData.weeklyGymTime += _elapsedSeconds;
        await dbHelper.updateUser(currentUserData);
      }
    }

    // Reset elapsed time
    _elapsedSeconds = 0;
  }

  String _formatTime(int seconds) {
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$secs';
  }
}