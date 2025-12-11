// lib/screens/workout_list_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'exercise_selection_screen.dart';
import '../widgets/workout_dialog.dart';

class WorkoutListScreen extends StatefulWidget {
  const WorkoutListScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends State<WorkoutListScreen> {
  final dbHelper = DatabaseHelper();

  // Changed to store the day of the week name (e.g., "Thursday")
  String _selectedDayOfWeek = DateFormat('EEEE').format(DateTime.now());
  String? _currentUserUid;
  Stream<List<Workout>>? _currentWorkoutsStream;

  // List of days for the dropdown
  final List<String> _daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserUid();
    // Initialize with the current day of the week name
    _selectedDayOfWeek = DateFormat('EEEE').format(DateTime.now());
  }

  void _loadCurrentUserUid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserUid = user.uid;
        _updateWorkoutsStream(_selectedDayOfWeek); // Pass the day of week name
      });
      print('WorkoutListScreen: Current User UID: $_currentUserUid');
    } else {
      print('WorkoutListScreen: No user logged in. Cannot load workouts.');
    }
  }

  // MODIFIED: _updateWorkoutsStream now takes a dayOfWeek name
  void _updateWorkoutsStream(String dayOfWeek) {
    if (_currentUserUid != null) {
      _currentWorkoutsStream = dbHelper.getWorkoutsStream(_currentUserUid!, dayOfWeek);
    } else {
      _currentWorkoutsStream = null;
    }
    setState(() {});
  }

  Future<void> _addWorkout() async {
    if (_currentUserUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add workouts.')),
      );
      return;
    }

    // Navigate to ExerciseSelectionScreen, passing the _selectedDayOfWeek
    final Exercise? selectedExercise = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseSelectionScreen(
          currentSelectedDay: DateFormat('yyyy-MM-dd').format(DateTime.now()), // Pass current date
          selectedDayOfWeek: _selectedDayOfWeek, // NEW: Pass the selected day of week name
          currentUserUid: _currentUserUid,
        ),
      ),
    );

    

    // If an exercise was selected (or created and then selected)
    // The WorkoutDialog will be shown from ExerciseSelectionScreen's callback
    // So no need to call _showWorkoutDialog here directly if it's handled by ExerciseSelectionScreen's return
    // However, if ExerciseSelectionScreen *pops* back with a result, you might process it here.
    // Given our current flow where WorkoutDialog is shown by ExerciseSelectionScreen, this `if` block is mostly for
    // potential future direct returns from ExerciseSelectionScreen.
    if (selectedExercise != null) {
      // Logic for selected exercise (e.g., show a snackbar, refresh list if not streamed)
      // The actual workout saving flow now starts from ExerciseSelectionScreen -> WorkoutDialog
      print('Exercise ${selectedExercise.name} confirmed for $_selectedDayOfWeek. WorkoutDialog should appear.');
    }
  }

  // This method is called by ExerciseSelectionScreen's onConfirmExercise callback
  void _showWorkoutDialog(Exercise exercise, String specificDate, String dayOfWeek, {Workout? existingWorkout}) {
    showDialog(
      context: context,
      builder: (context) => WorkoutDialog(
        uid: _currentUserUid!,
        specificDate: specificDate, // The actual date (yyyy-MM-dd)
        dayOfWeek: dayOfWeek, // The day name (e.g., "Thursday")
        exercise: exercise,
        existingWorkout: existingWorkout,
        onSave: (savedWorkout) async {
          await dbHelper.saveWorkout(savedWorkout);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${savedWorkout.name} added/updated successfully!')),
            );
          }
        },
      ),
    );
  }

  Future<void> _updateWorkout(Workout workout) async {
    if (_currentUserUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to update workouts.')),
      );
      return;
    }

    final Exercise dummyExercise = Exercise(
      id: workout.exerciseId ?? const Uuid().v4(),
      name: workout.exerciseName,
      category: workout.category,
      targetMuscles: [''], // Placeholder as targetMuscles is not stored in Workout
      videoLink: null,
      description: null,
      equipment: null,
      difficulty: workout.difficulty, // Use difficulty from workout
    );

    // MODIFIED: Pass specificDate and dayOfWeek from the existing workout
    _showWorkoutDialog(
      dummyExercise,
      workout.date, // Pass the specific date of the existing workout
      workout.dayOfWeek, // Pass the day of week of the existing workout
      existingWorkout: workout,
    );
  }

  Future<void> _deleteWorkout(String workoutId) async {
    if (_currentUserUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to delete workouts.')),
      );
      return;
    }
    await dbHelper.deleteWorkout(_currentUserUid!, workoutId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout deleted successfully!')),
      );
    }
  }

  IconData _getWorkoutIcon(String type) {
    switch (type.toLowerCase()) {
      case 'weightlifting':
        return Icons.fitness_center;
      case 'cardio':
        return Icons.directions_run;
      case 'calisthenics':
        return Icons.self_improvement;
      case 'yoga':
        return Icons.spa;
      case 'flexibility':
        return Icons.accessibility_new;
      default:
        return Icons.sports_gymnastics;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Workouts',
          textAlign: TextAlign.center,
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
          // MODIFIED: Dropdown for selecting day of the week
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<String>(
              value: _selectedDayOfWeek,
              icon: const Icon(Icons.calendar_today, color: Colors.white),
              dropdownColor: Theme.of(context).primaryColorDark,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              underline: Container(), // Remove underline
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedDayOfWeek = newValue;
                    _updateWorkoutsStream(_selectedDayOfWeek); // Filter by day of week
                  });
                }
              },
              items: _daysOfWeek.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addWorkout,
        backgroundColor: Colors.deepOrangeAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: const Icon(Icons.add, size: 30),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/barbell_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: _currentUserUid == null
            ? const Center(child: Text('Loading user data...', style: TextStyle(color: Colors.white70)))
            : _currentWorkoutsStream == null
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : StreamBuilder<List<Workout>>(
                    stream: _currentWorkoutsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      }
                      if (snapshot.hasError) {
                        print('WorkoutStream Error: ${snapshot.error}');
                        return Center(child: Text('Error loading workouts: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sentiment_dissatisfied, size: 50, color: Colors.grey[400]),
                              const SizedBox(height: 20),
                              Text(
                                'No workouts added for $_selectedDayOfWeek yet. Let\'s create one!',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 18, color: Colors.white70, fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _addWorkout,
                                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                                label: const Text('Add Your First Workout', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepOrangeAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final workouts = snapshot.data!;
                      return ListView.builder(
                        itemCount: workouts.length,
                        itemBuilder: (context, index) {
                          final workout = workouts[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            elevation: 4,
                            color: Colors.white.withOpacity(0.9),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: ListTile(
                                leading: Icon(_getWorkoutIcon(workout.type), color: Colors.deepOrangeAccent[400]),
                                title: Text(
                                  '${workout.name} (${workout.category})',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrangeAccent,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sets: ${workout.sets}, Reps: ${workout.reps}, Weight: ${workout.weight?.toStringAsFixed(1) ?? 'N/A'}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      'Difficulty: ${workout.difficulty}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    if (workout.notes != null && workout.notes!.isNotEmpty)
                                      Text(
                                        'Notes: ${workout.notes}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    Text(
                                      'Recorded: ${DateFormat('MMM dd, BCE HH:mm').format(DateTime.parse(workout.timestamp))}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      'Scheduled Day: ${workout.dayOfWeek}', // Display the scheduled day of week
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                          onPressed: () => _updateWorkout(workout),
                                          icon: const Icon(Icons.edit, color: Colors.white)),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                          onPressed: () => _deleteWorkout(workout.id),
                                          icon: const Icon(Icons.delete, color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
