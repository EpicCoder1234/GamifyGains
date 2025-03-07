import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:gamify_gains/models/gym_session.dart';
import 'package:gamify_gains/screens/gym_session_screen.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../models/workout.dart';
import 'workout_list_screen.dart';
import 'diet_screen.dart';
import '../widgets/llm_integration_main.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/workout_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final dbHelper = DatabaseHelper();
  final workoutService = WorkoutService(); // Add this line
  List<Workout> workouts = [];
  ValueNotifier<String> elapsedTime = ValueNotifier<String>("00:00:00");
  ValueNotifier<int> weeklyGymTime = ValueNotifier<int>(0);
  bool isWorkoutRunning = false;
  final service = FlutterBackgroundService();
  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializeService();
    });
    _loadWorkouts(DateFormat('EEEE').format(DateTime.now()));
    _loadWeeklyGymTime();
    _listenToStream();
  }

  void _listenToStream() {
  _streamSubscription = workoutService.service.on('update').listen((event) {
    if (mounted) {
      setState(() {
        if (event != null &&
            event is Map<String, dynamic> &&
            event.containsKey("current_time")) {
          elapsedTime.value = event["current_time"] as String;
        }
      });
    }
  });
}
  @override
  void dispose() {
    elapsedTime.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

Future<void> initializeService() async {
  await workoutService.initializeService(); // Use WorkoutService
}

  Future<void> _loadWorkouts(String day) async {
    workouts = await dbHelper.getWorkouts(day);
    setState(() {});
  }

Future<void> _loadWeeklyGymTime() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final currentUserData = await dbHelper.getUser(user.uid);
      if (currentUserData != null) {
        weeklyGymTime.value = currentUserData.weeklyGymTime;
      } else {
        print("User data not found in Firestore for UID: ${user.uid}");
      }
    } else {
      print("No user logged in");
    }
  }

  void _startWorkout() async {
  final service = FlutterBackgroundService();
  var isRunning = await service.isRunning();
  if (!isRunning) {
    await service.startService();
  }
  workoutService.startTimer(); // Use WorkoutService
  setState(() {
    isWorkoutRunning = true;
  });
}

void _stopWorkout() {
  workoutService.stopTimer(); // Use WorkoutService
  setState(() {
    isWorkoutRunning = false;
    elapsedTime.value = "00:00:00";
  });
  _loadWeeklyGymTime();
}

  @override
Widget build(BuildContext context) {
  String currentDay = DateFormat('EEEE').format(DateTime.now());

  return MaterialApp(
    theme: ThemeData(
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.black87),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
    ),
    home: Scaffold(
      body: Stack(
        children: [
          // Background and main content (unchanged)
                Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/barbell_background.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildWorkoutSummary(currentDay),
                          const SizedBox(height: 20),
                          _buildWorkoutSection(), // Renamed for clarity
                          const SizedBox(height: 20),
                          if (isWorkoutRunning)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: _buildTimerBottomSheet(), // Extracted to a separate method
                            ),
                          _buildAI(), // Assume this is a section
                          const SizedBox(height: 20),
                          _buildDietPlan(),
                          const SizedBox(height: 20),
                          _buildLeaderboard(),
                          const SizedBox(height: 20),
                          _buildMusicPlayer(),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    ),
  );
}
Widget _buildTimerBottomSheet() {
  return Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
    ),
    padding: const EdgeInsets.all(16.0),
    child: Center(
      child: ValueListenableBuilder<String>(
        valueListenable: elapsedTime,
        builder: (context, time, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Workout Time: $time",
                style: const TextStyle(fontSize: 18),
              ),
              ElevatedButton(
                onPressed: () {
                  service.invoke("stopService");
                  _stopWorkout();
                },
                child: const Text("Stop"),
              ),
            ],
          );
        },
      ),
    ),
  );
}

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Gamify Gains',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            Text(
              'Welcome! Ready for a good workout?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Image.asset(
          'assets/gamify_gains_logo.png', // Replace with your logo path
          height: 50,
        ),
      ],
    );
  }

Widget _buildWorkoutSummary(String currentDay) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7), // Slightly transparent black
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              currentDay,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), // Bigger day text
            ),
          ),
          const SizedBox(height: 10),
          if (workouts.isEmpty)
            const Center(
                child: Text('No workouts added yet.',
                    style: TextStyle(color: Colors.white)))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: workouts.map((workout) => Padding( // Added padding for spacing
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.white)),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16), // Bigger workout text
                              children: <TextSpan>[
                                TextSpan(
                                    text: '${workout.sets}',
                                    style: const TextStyle(color: Colors.red)),
                                const TextSpan(text: ' sets of '),
                                TextSpan(
                                    text: '${workout.reps}',
                                    style: const TextStyle(color: Colors.red)),
                                const TextSpan(text: ' rep '),
                                TextSpan(text: workout.name),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
            ),
          const SizedBox(height: 10),
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const WorkoutListScreen()),
                ).then((value) => _loadWorkouts(currentDay));
              },
              child: const Text('Go to workout plan'),
            ),
          ),
        
        ],
      ),
    );
  }

    Widget _buildWorkoutSection() { // Renamed for clarity
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to start your workout?:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: (){
              Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GymSessionScreen(), // Navigate to your timer screen
                    ),
                  );
            },
            child: const Text('Start Workout'),
          ),
        ],
      ),
    );
  }

   Widget _buildAI() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Image.asset(
          'assets/gemini.png', // Replace with your logo path
          height: 50,
        ),
        Expanded(
                child: ElevatedButton(
                  onPressed: () { Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LLMIntegrationScreen(selectedDay: "Tuesday"), // Navigate to your AI screen
                    ),
                  );},
                  child: const Text('Talk with AI'),
                ),
              ),
              const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildDietPlan() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your diet plan:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text('Talk with GeminiAI to create a diet plan!'),
          const SizedBox(height: 10),
          Row(
            children: [
      
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => DietScreen()));
                  },
                  child: const Text('Modify Diet'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leaderboard',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Divider(color: Colors.grey),
          ...List.generate(
              5,
              (index) => _buildLeaderboardItem(index + 1, "Bob Joe",
                  "${(4.6 - index * 0.4).toStringAsFixed(1)}hrs")),
        ],
      ),
    );
  }
   Widget _buildLeaderboardItem(int rank, String name, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$rank', style: const TextStyle(color: Colors.white)),
          Text(name, style: const TextStyle(color: Colors.white)),
          Text(time, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
   Widget _buildMusicPlayer() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Scorsese Baby Dad \n SZA'),
          Row(
            children: [
              IconButton(
                  onPressed: () {}, icon: const Icon(Icons.skip_previous)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.play_arrow)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.skip_next)),
            ],
          ),
          const Text('0:34     -1:59'),
        ],
      ),
    );
  }
}