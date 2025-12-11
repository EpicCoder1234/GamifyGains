// lib/screens/gym_session_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import '../models/gym_session.dart';
import '../models/user.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../services/auth_service.dart';

class GymSessionScreen extends StatefulWidget {
  const GymSessionScreen({super.key});

  @override
  State<GymSessionScreen> createState() => _GymSessionScreenState();
}

class _GymSessionScreenState extends State<GymSessionScreen> {
  final StopWatchTimer _stopWatchTimer = StopWatchTimer(mode: StopWatchMode.countUp);
  final _isHours = true;
  String? _currentUserUid;
  final AuthService _authService = AuthService();

  GymSession? _currentSession;
  bool _isWorkoutActive = false; // Tracks if a session is actively running

  @override
  void initState() {
    super.initState();
    _loadCurrentUserUid();
  }

  void _loadCurrentUserUid() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserUid = user.uid;
      });
      print('DEBUG: GymSessionScreen - Current User UID (from FirebaseAuth): $_currentUserUid');
    } else {
      print('DEBUG: GymSessionScreen - No user currently logged in (FirebaseAuth.currentUser is null).');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to start a workout.')),
        );
        Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _stopWatchTimer.dispose();
    super.dispose();
  }

  void _startWorkout() async {
    if (_currentUserUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in.')),
        );
      }
      return;
    }

    try {
      // Check for completion *before* attempting to start
      bool hasCompleted = await DatabaseHelper().hasCompletedGymSessionToday(_currentUserUid!);
      if (hasCompleted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have already completed a gym session today.')),
          );
          Navigator.of(context).pop(); // Go back to home screen
        }
        return;
      }

      final newSession = GymSession(
        id: const Uuid().v4(),
        uid: _currentUserUid!,
        startTime: DateTime.now(),
        duration: 0,
        isCompleted: false,
      );

      await DatabaseHelper().saveGymSession(newSession);
      print('Initial gym session saved: ${newSession.id}');

      setState(() {
        _isWorkoutActive = true;
        _currentSession = newSession;
      });
      _stopWatchTimer.onStartTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout session started!')),
        );
      }
    } catch (e) {
      print('Error starting workout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting workout: ${e.toString()}')),
        );
      }
    }
  }

  void _stopAndSaveSession() async {
    if (!_isWorkoutActive || _currentSession == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No workout in progress to stop.')),
        );
      }
      return;
    }

    _stopWatchTimer.onStopTimer();

    final int rawTime = _stopWatchTimer.rawTime.value;
    final int durationInSeconds = (rawTime / 1000).round();

    if (durationInSeconds <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout duration was 0 seconds. Not saving.')),
        );
      }
      if (_currentSession != null) {
        try {
          await DatabaseHelper().deleteGymSessionFirestore(_currentUserUid!, _currentSession!.id);
          print('Deleted 0-duration session: ${_currentSession!.id}');
        } catch (e) {
          print('Error deleting 0-duration session: $e');
        }
      }
      _stopWatchTimer.onResetTimer();
      setState(() {
        _isWorkoutActive = false;
        _currentSession = null;
      });
      // Do not pop here if user wants to see the screen and perhaps start another.
      // Or pop if this screen's purpose is only for an active session.
      // For now, let's pop to return to the home screen after stopping.
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      final updatedSession = _currentSession!.copyWith(
        duration: durationInSeconds,
        isCompleted: true,
      );
      await DatabaseHelper().updateGymSession(updatedSession);
      print('Gym session updated and marked as completed: ${updatedSession.id}');

      if (_currentUserUid != null) {
        User? currentUser = await DatabaseHelper().getUser(_currentUserUid!);
        if (currentUser != null) {
          currentUser.weeklyGymTime = (currentUser.weeklyGymTime ?? 0) + durationInSeconds;
          await DatabaseHelper().updateUser(currentUser);
          print('User weeklyGymTime updated in Firestore: ${currentUser.weeklyGymTime} seconds');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Workout session saved and updated! Total weekly gym time: ${(currentUser.weeklyGymTime ?? 0) ~/ 60} minutes')),
            );
          }
        } else {
          print('User data not found in Firestore for UID: $_currentUserUid');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Workout session saved, but user data not found in Firestore.')),
            );
          }
        }
      }
    } catch (e) {
      print('Error saving gym session or updating user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving workout session: $e')),
        );
      }
    } finally {
      _stopWatchTimer.onResetTimer();
      setState(() {
        _isWorkoutActive = false;
        _currentSession = null;
      });
      if (mounted) {
        Navigator.of(context).pop(); // Always pop to return to home screen after save/error
      }
    }
  }

  void _logout() async {
    // Implement logout confirmation to avoid losing active session data
    if (_isWorkoutActive) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Workout in Progress'),
          content: const Text('A workout is currently active. Are you sure you want to log out? Your current session will not be saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Log Out Anyway'),
            ),
          ],
        ),
      );
      if (confirm == false || confirm == null) {
        return;
      } else {
        // Discard the current session before logging out
        _stopWatchTimer.onResetTimer();
        setState(() {
          _isWorkoutActive = false;
          _currentSession = null;
        });
        if (_currentSession != null && _currentUserUid != null) {
          try {
            await DatabaseHelper().deleteGymSessionFirestore(_currentUserUid!, _currentSession!.id);
            print('Deleted incomplete session on logout: ${_currentSession!.id}');
          } catch (e) {
            print('Error deleting incomplete session on logout: $e');
          }
        }
      }
    }

    try {
      await _authService.signOut();
      print('User logged out successfully.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully.')),
        );
        // Navigate to the authentication screen and remove all previous routes
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    } catch (e) {
      print('Error during logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during logout: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_currentUserUid == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Current Workout Session',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/barbell_background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.4),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Display the timer and stop/reset buttons IF a workout is active
                if (_isWorkoutActive)
                  Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Workout in Progress:',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.orange),
                            ),
                            const SizedBox(height: 10),
                            StreamBuilder<int>(
                              stream: _stopWatchTimer.rawTime,
                              initialData: _stopWatchTimer.rawTime.value,
                              builder: (context, snapshot) {
                                final value = snapshot.data;
                                final displayTime = value != null ? StopWatchTimer.getDisplayTime(value, hours: _isHours) : '00:00:00';
                                return Text(
                                  displayTime,
                                  style: const TextStyle(fontSize: 55.0, fontWeight: FontWeight.bold, color: Colors.black87),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: _stopAndSaveSession,
                        icon: const Icon(Icons.stop, color: Colors.white, size: 28),
                        label: const Text(
                          'Stop & Save Workout',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 8,
                          shadowColor: Colors.red.shade900.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // This button now always offers to discard/reset
                          final bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Discard Workout?'),
                              content: const Text('Are you sure you want to reset the timer and discard this workout session?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Discard'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            _stopWatchTimer.onResetTimer();
                            setState(() {
                              _isWorkoutActive = false; // Reset to show the start button again
                              _currentSession = null;
                            });
                            // If a session was started (even 0 duration), try to delete it
                            if (_currentSession != null && _currentUserUid != null) {
                              try {
                                await DatabaseHelper().deleteGymSessionFirestore(_currentUserUid!, _currentSession!.id);
                                print('Discarded and deleted incomplete session: ${_currentSession!.id}');
                              } catch (e) {
                                print('Error deleting discarded session: $e');
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
                        label: const Text(
                          'Reset/Discard',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 8,
                          shadowColor: Colors.blueGrey.shade900.withOpacity(0.5),
                        ),
                      ),
                    ],
                  )
                else
                  // If no workout is active, show the start button.
                  // This part now uses the StreamBuilder directly.
                  StreamBuilder<bool>(
                    stream: DatabaseHelper().hasCompletedGymSessionTodayStream(_currentUserUid!),
                    initialData: false,
                    builder: (context, snapshot) {
                      final bool hasCompletedSessionToday = snapshot.data ?? false;
                      print('DEBUG: GymSessionScreen - Has completed session today (StreamBuilder): $hasCompletedSessionToday');

                      return Column(
                        children: [
                          Text(
                            hasCompletedSessionToday ? 'Workout Completed for Today!' : 'Ready to start your workout?',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton.icon(
                            onPressed: hasCompletedSessionToday ? null : _startWorkout, // Disable if completed
                            icon: Icon(Icons.play_arrow, color: hasCompletedSessionToday ? Colors.grey : Colors.white, size: 28),
                            label: Text(
                              hasCompletedSessionToday ? 'Workout Completed Today' : 'Start Workout',
                              style: TextStyle(color: hasCompletedSessionToday ? Colors.grey : Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasCompletedSessionToday ? Colors.black54 : Colors.green.shade700,
                              foregroundColor:hasCompletedSessionToday ? Colors.white: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: hasCompletedSessionToday ? 0 : 8,
                              shadowColor: hasCompletedSessionToday ? Colors.transparent : Colors.green.shade900.withOpacity(0.5),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}