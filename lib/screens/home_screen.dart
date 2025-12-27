import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gamify_gains/screens/analytics_screen.dart';
import 'package:gamify_gains/screens/auth/auth_screen.dart'; // Add this line
import 'package:firebase_auth/firebase_auth.dart' hide User; // Import Firebase Auth
import 'package:gamify_gains/models/gym_session.dart';
import 'package:gamify_gains/screens/gym_session_screen.dart'; // Keep this import if you still use this screen for other purposes
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../models/workout.dart';
import '../models/user.dart'; // Import the User model
import '../models/diet_plan.dart';
import 'workout_list_screen.dart';
import 'diet_screen.dart';
import 'full_leaderboard_screen.dart';
import '../widgets/llm_integration_main.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/workout_service.dart';
import 'package:uuid/uuid.dart'; // Import uuid for session ID generation
import '../services/auth_service.dart'; // NEW: Import your AuthService
import 'edit_profile_screen.dart'; // NEW: Import your EditProfileScreen
import '../widgets/my_gallery_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final dbHelper = DatabaseHelper();
  final workoutService = WorkoutService();
  final AuthService _authService = AuthService();
  Stream<List<Workout>>? _currentWorkoutsStream;
  ValueNotifier<String> elapsedTime = ValueNotifier<String>("00:00:00");
  ValueNotifier<int> weeklyGymTime = ValueNotifier<int>(0);
  bool isWorkoutRunning = false;
  final service = FlutterBackgroundService();
  StreamSubscription? _streamSubscription;
  String? _currentUserUid; // To store the authenticated user's UID
  Stream<DietPlan?>? _currentDayDietPlanStream; // Stream for today's diet plan

  User? _currentUserProfile; // NEW: To store the current user's full profile

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await initializeService();
      _loadCurrentUserAndSetupStreams(); // This now also loads the user profile
    });
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

  // Function to load current user UID, setup all user-dependent streams, and load user profile
  void _loadCurrentUserAndSetupStreams() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserUid = user.uid;
      // NEW: Fetch and set the current user's full profile
      final userProfile = await dbHelper.getUser(_currentUserUid!);
      if (mounted) {
        setState(() {
          _currentUserProfile = userProfile;
          _updateCurrentDayDietPlanStream(); // Setup diet plan stream using the loaded UID
          _currentWorkoutsStream = dbHelper.getWorkoutsStream(_currentUserUid!, DateFormat('EEEE').format(DateTime.now()));
        });
      }
    } else {
      print('No user currently logged in. Navigating back to authentication.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/auth');
      });
    }
  }

  // Update the diet plan stream whenever the selected day or user changes
  void _updateCurrentDayDietPlanStream() {
    if (_currentUserUid != null) {
      _currentDayDietPlanStream = dbHelper.getDietPlanStream(_currentUserUid!, DateFormat('EEEE').format(DateTime.now()));
    } else {
      _currentDayDietPlanStream = null; // Clear stream if no user
    }
    setState(() {}); // Rebuild to update StreamBuilder with the new stream
  }

  @override
  void dispose() {
    elapsedTime.dispose();
    _streamSubscription?.cancel();
    weeklyGymTime.dispose(); // Ensure weeklyGymTime ValueNotifier is disposed
    super.dispose();
  }


  Future<void> initializeService() async {
    await workoutService.initializeService(); // Use WorkoutService
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
    _loadWeeklyGymTime(); // Reload weekly gym time after stopping workout
    setState(() {
      isWorkoutRunning = false;
      elapsedTime.value = "00:00:00";
    });
  }

  // NEW: Function to handle logging out
  void _logout() async {
    try {
      await _authService.signOut(); // Call signOut from AuthService
      print('User logged out successfully from HomeScreen.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully.')),
        );
        // Navigate to your login/authentication screen after logout
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    } catch (e) {
      print('Error during logout from HomeScreen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during logout: $e')),
        );
      }
    }
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
            backgroundColor: const Color.fromARGB(255, 2, 0, 32),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ),
      home: Scaffold(
               // NEW: Add the Drawer
        drawer: Drawer(
          // Set the entire drawer background to a very dark blue/black
          backgroundColor: const Color(0xFF0A0A1A), // Your very dark blue/black
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              UserAccountsDrawerHeader(
                accountName: Text(
                  _currentUserProfile?.name ?? 'Guest User',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                accountEmail: Text(
                  FirebaseAuth.instance.currentUser?.email ?? 'Not logged in',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary, // Use your primary orange
                  child: const Icon(
                    Icons.person_outline,
                    size: 50,
                    color: Colors.white, // White icon on orange background
                  ),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).colorScheme.primary.withOpacity(0.8), Colors.black], // Orange to black gradient
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              
              // Age, Weight, Height ListTiles with black background and white text
              // Wrapped in Containers to control their background and spacing
              Container(
                color: Colors.black, // Explicitly black background for this section
                margin: const EdgeInsets.symmetric(vertical: 4.0), // Add some vertical spacing
                child: ListTile(
                  leading: const Icon(Icons.cake, color: Colors.white), // White icon
                  title: Text(
                    'Age: ${_currentUserProfile?.age ?? 'N/A'} years',
                    style: const TextStyle(fontSize: 16, color: Colors.white), // White text
                  ),
                ),
              ),
              Container(
                color: Colors.black, // Explicitly black background for this section
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: const Icon(Icons.fitness_center, color: Colors.white), // White icon
                  title: Text(
                    'Weight: ${_currentUserProfile?.weight?.toStringAsFixed(1) ?? 'N/A'} lbs',
                    style: const TextStyle(fontSize: 16, color: Colors.white), // White text
                  ),
                ),
              ),
              Container(
                color: Colors.black, // Explicitly black background for this section
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: const Icon(Icons.height, color: Colors.white), // White icon
                  title: Text(
                    'Height: ${_currentUserProfile?.height?.toStringAsFixed(1) ?? 'N/A'} inches',
                    style: const TextStyle(fontSize: 16, color: Colors.white), // White text
                  ),
                ),
              ),
              const Divider(color: Colors.white38), // White divider for consistency
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.deepOrangeAccent), // Orange edit icon
                title: const Text('Edit Profile', style: TextStyle(fontSize: 16, color: Colors.deepOrangeAccent)), // Orange text
                onTap: () async {
                  Navigator.pop(context); // Close the drawer first
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                  );
                  // After returning from EditProfileScreen, reload user data to update drawer
                  _loadCurrentUserAndSetupStreams(); // Reloads user profile and streams
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent), // Red logout icon
                title: const Text('Logout', style: TextStyle(fontSize: 16, color: Colors.redAccent)), // Red logout text
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  _logout(); // Call your existing logout function
                },
              ),
            ],
          ),
        ),
        appBar: AppBar(
          title: const Text('Gamify Gains', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.black, // Use a solid color for consistency
          elevation: 0,
          leading: Builder( // NEW: Add a Builder to access Scaffold context for drawer
            builder: (BuildContext context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white), // 3-bar menu icon
                onPressed: () {
                  Scaffold.of(context).openDrawer(); // Open the drawer
                },
                tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
              );
            },
          ),
          actions: [
            // Moved logout button from _buildHeader to AppBar actions for better standard practice
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ],
        ),
        extendBodyBehindAppBar: false, // Set to false since AppBar is no longer transparent over body
        body: Container( // Wrap body content in a Container for background image
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
                  // No longer call _buildHeader here, as AppBar now handles title and logout
                  _buildWelcomeMessage(_currentUserProfile?.name ?? 'Guest User'),
                  const SizedBox(height: 20), // Add some initial spacing
                  _buildWorkoutSummary(currentDay),
                  const SizedBox(height: 20),
                  _buildWorkoutSection(),
                  const SizedBox(height: 20),
                  const MyGalleryWidget(),
                  const SizedBox(height: 20),
                  _buildAI(),
                  const SizedBox(height: 20),
                  _buildAnalytics(),
                  const SizedBox(height: 20),
                  _buildDietPlan(),
                  const SizedBox(height: 20),
                  _buildLeaderboard()

                ],
              ),
            ),
          ),
        ),
     
        bottomSheet: isWorkoutRunning ? _buildTimerBottomSheet() : null, // Use bottomSheet for cleaner overlay
      ),
    );
  }
  Widget _buildWelcomeMessage(String userName) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0), 
    child: Center( // Center the text horizontally
      child: Text(
        'Welcome, $userName! Ready for a good workout?',
        textAlign: TextAlign.center, 
        style: TextStyle(
          fontSize: 22, 
          fontWeight: FontWeight.bold, 
          color: Colors.white, 
          letterSpacing: 1.2, 
          shadows: [ 
            Shadow(
              blurRadius: 3.0,
              color: Colors.orange.withOpacity(0.5),
              offset: Offset(2.0, 2.0),
            ),
          ],
        ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon( 
                  onPressed: () {
                    service.invoke("stopService"); // stop backgreound service
                    _stopWorkout(); 
                  },
                  icon: const Icon(Icons.stop, color: Colors.white),
                  label: const Text("Stop", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Removed _buildHeader elements are now in AppBar and Drawer

  Widget _buildWorkoutSummary(String currentDay) {
  return Container(
    padding: const EdgeInsets.all(16.0),
    decoration: BoxDecoration(
     
      color: Colors.blueGrey[900]?.withOpacity(0.9), 
      borderRadius: BorderRadius.circular(15.0), 
      border: Border.all(
          color: const Color.fromARGB(255, 216, 130, 0), 
          width: 2,
        ),
      boxShadow: [ 
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          spreadRadius: 2,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            currentDay,
            style: const TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2, 
              shadows: [ 
                Shadow(
                  blurRadius: 2.0,
                  color: Colors.black,
                  offset: Offset(1.0, 1.0),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15), 
        _currentUserUid == null // user UID loaded?
            ? const Center(

                child: Text(
                  'Please log in to see your workouts.',

                  style: TextStyle(color: Colors.white70, fontSize: 16), 

                  textAlign: TextAlign.center,
                ),
              )
            : StreamBuilder<List<Workout>>(
                stream: _currentWorkoutsStream, 
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)); 
                  }
                  if (snapshot.hasError) {
                    print('HomeScreen WorkoutStream Error: ${snapshot.error}');
                    return Center(
                      child: Text(
                        'Error loading workouts: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 14), // Red for error
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'No workouts added for today.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const WorkoutListScreen(),
                                ),
                              ).then((value) => _loadCurrentUserAndSetupStreams());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(255, 216, 130, 0), 
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25.0), 
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              elevation: 5, 
                            ),
                            child: const Text('Add Workout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    );
                  }

                  // Display the list of workouts
                  final workouts = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: workouts.map((workout) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0), 
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18), 
                          const SizedBox(width: 8), 
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 17), 
                                children: <TextSpan>[
                                  TextSpan(
                                      text: '${workout.sets}',
                                      style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)), 
                                  const TextSpan(text: ' sets of '),
                                  TextSpan(
                                      text: '${workout.reps}',
                                      style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                                  const TextSpan(text: ' rep '),
                                  TextSpan(text: workout.name, style: const TextStyle(fontWeight: FontWeight.w600)), 
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  );
                },
              ),
        const SizedBox(height: 20), 
        Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const WorkoutListScreen()),
              ).then((value) => _loadCurrentUserAndSetupStreams()); 
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromARGB(255, 216, 130, 0),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              elevation: 5,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            child: const Text('Go to Workout Plan'), 
          ),
        ),
      ],
    ),
  );
}

// Part of lib/screens/home_screen.dart (within _HomeScreenState)

Widget _buildWorkoutSection() {

  final DatabaseHelper _dbHelper = DatabaseHelper(); 
  final String? currentUserUid = _currentUserUid; 

  if (currentUserUid == null) {
 
    return const SizedBox.shrink();
  }

  return StreamBuilder<bool>(
    stream: _dbHelper.hasCompletedGymSessionTodayStream(currentUserUid),
    initialData: false, 
    builder: (context, snapshot) {
      final bool hasCompletedSessionToday = snapshot.data ?? false;
      print('DEBUG: _buildWorkoutSection - Has completed session today: $hasCompletedSessionToday'); 

      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.blueGrey[900]?.withOpacity(0.9), 
          borderRadius: BorderRadius.circular(15.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                hasCompletedSessionToday ? 'Workout Completed for Today!' : 'Ready to start your workout?',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
            ),
            const SizedBox(height: 15),
            Center(
              child: ElevatedButton.icon(
                onPressed: hasCompletedSessionToday ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GymSessionScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasCompletedSessionToday ? Colors.black54 : Colors.greenAccent, 
                  foregroundColor: hasCompletedSessionToday ? Colors.grey : Colors.black, 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  elevation: hasCompletedSessionToday ? 0 : 7, 
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                icon: Icon(Icons.timer, color: hasCompletedSessionToday ? Colors.grey : Colors.white),
                label: Text(
                  hasCompletedSessionToday ? 'Completed' : 'Start Workout', 
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
 
Widget _buildAI() {
  return Container( 
    padding: const EdgeInsets.all(16.0),
    decoration: BoxDecoration(
      color: Colors.blueGrey[900]?.withOpacity(0.9), 
      borderRadius: BorderRadius.circular(15.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          spreadRadius: 2,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Image.asset(
          'assets/gemini.png', 
          height: 60, 
        ),
        const SizedBox(width: 15), 
        Expanded(
          child: ElevatedButton.icon( 
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LLMIntegrationScreen(selectedDay: "Tuesday"), 
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromARGB(255, 216, 130, 0), 
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              elevation: 5,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.psychology_outlined, color: Colors.white), 
            label: const Text('Talk with AI'),
          ),
        ),
      ],
    ),
  );
}


Widget _buildDietPlan() {
  String currentDay = DateFormat('EEEE').format(DateTime.now()); 

  return Container(
    padding: const EdgeInsets.all(16.0),
    decoration: BoxDecoration(
      color: Colors.blueGrey[800]?.withOpacity(0.9),
      borderRadius: BorderRadius.circular(15.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          spreadRadius: 2,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Diet Plan Today:',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 15),
        _currentUserUid == null
            ? const Center(
                child: Text(
                  'Please log in to see your diet plan.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              )
            : StreamBuilder<DietPlan?>(
                stream: _currentDayDietPlanStream, 
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }
                  if (snapshot.hasError) {
                    print('HomeScreen DietStream Error: ${snapshot.error}');
                    return Center(
                        child: Text('Error loading diet plan: ${snapshot.error}',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 14)));
                  }

                  final DietPlan? diet = snapshot.data;

                  if (diet == null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'No diet plan set for today.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) => DietScreen()));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(255, 216, 130, 0), 
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25.0),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                              elevation: 5,
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            child: const Text('Set Today\'s Diet'),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (diet.isCheatDay)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Today is a CHEAT DAY! Enjoy your meals!',
                              style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDietMealItem('Breakfast', diet.breakfast),
                              _buildDietMealItem('Lunch', diet.lunch),
                              _buildDietMealItem('Dinner', diet.dinner),
                              diet.hasSnack
                                  ? _buildDietMealItem('Snack', diet.snackDetails ?? 'Not specified')
                                  : const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 4.0),
                                      child: Text('No snack planned.', style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.white70)),
                                    ),
                            ],
                          ),
                        const SizedBox(height: 15),
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) => DietScreen()));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange, // Consistent color
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25.0),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                              elevation: 5,
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            child: const Text('Modify Diet Plan'),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
      ],
    ),
  );
}

// Helper method for diet plan meal items
Widget _buildDietMealItem(String mealType, String mealDetails) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.restaurant_menu, color: Colors.white70, size: 18), 
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, color: Colors.white),
              children: [
                TextSpan(text: '$mealType: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: mealDetails),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}


  Widget _buildLeaderboard() {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.blueGrey[900]?.withOpacity(0.9), 
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          spreadRadius: 2,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Global Leaderboard', // More prominent title
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                blurRadius: 2.0,
                color: Colors.black,
                offset: Offset(1.0, 1.0),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.blueGrey, thickness: 1.5, height: 25), // Thicker, more subtle divider

        // Display the current user's weekly gym time at the top, slightly more emphasized
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.3), // Light highlight for "Your Time"
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: weeklyGymTime,
            builder: (context, timeInSeconds, child) {
              final hours = (timeInSeconds / 3600).floor();
              final minutes = ((timeInSeconds % 3600) / 60).floor();
              final seconds = timeInSeconds % 60;
              final formattedTime = '${hours}h ${minutes}m ${seconds}s';
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Your Time:', style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 16)), // Brighter yellow
                  Text(formattedTime, style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 15),

        StreamBuilder<List<User>>( // This 'User' refers to your custom models/user.dart User class
          stream: dbHelper.getUsersStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            if (snapshot.hasError) {
              print('Error loading leaderboard: ${snapshot.error}');
              return const Center(child: Text('Error loading leaderboard', style: TextStyle(color: Colors.redAccent)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No users on leaderboard yet.', style: TextStyle(color: Colors.white70)));
            }

            final allSortedUsers = List<User>.from(snapshot.data!)
                .where((user) => (user.weeklyGymTime ?? 0) > 0)
                .toList();
            allSortedUsers.sort((a, b) => (b.weeklyGymTime ?? 0).compareTo(a.weeklyGymTime ?? 0));

            if (allSortedUsers.isEmpty) {
              return const Center(child: Text('Start logging workouts to appear on the leaderboard!', style: TextStyle(color: Colors.white70)));
            }

            int currentUserRank = -1;
            User? currentUserInList;
            if (currentUserId != null) {
              for (int i = 0; i < allSortedUsers.length; i++) {
                if (allSortedUsers[i].uid == currentUserId) {
                  currentUserRank = i + 1;
                  currentUserInList = allSortedUsers[i];
                  break;
                }
              }
            }

            final int displayCount = allSortedUsers.length < 5 ? allSortedUsers.length : 5;
            final List<User> topUsersForDisplay = allSortedUsers.sublist(0, displayCount);

            bool hasCurrentUserBeenDisplayed = false;
            if (currentUserInList != null && currentUserRank != -1 && currentUserRank <= displayCount) {
              hasCurrentUserBeenDisplayed = true;
            }

            return Column(
              children: [
                ...List.generate(
                  topUsersForDisplay.length,
                  (index) {
                    final user = topUsersForDisplay[index];
                    final hours = (user.weeklyGymTime! / 3600).floor();
                    final minutes = ((user.weeklyGymTime! % 3600) / 60).floor();
                    final seconds = user.weeklyGymTime! % 60;
                    final formattedTime = '${hours}h ${minutes}m ${seconds}s';
                    return _buildLeaderboardItem(
                      index + 1, // Rank
                      user.name,
                      formattedTime,
                      isCurrentUser: user.uid == currentUserId, // Highlight if it's the current user
                    );
                  },
                ),
                if (currentUserRank != -1 && currentUserInList != null && !hasCurrentUserBeenDisplayed)
                  Column(
                    children: [
                      if (currentUserRank > displayCount + 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('...', style: TextStyle(color: Colors.white70, fontSize: 16)),
                        ),
                      _buildLeaderboardItem(
                        currentUserRank,
                        "You (${currentUserInList.name})",
                        '${(currentUserInList.weeklyGymTime! / 3600).floor()}h ${((currentUserInList.weeklyGymTime! % 3600) / 60).floor()}m ${(currentUserInList.weeklyGymTime! % 60).floor()}s',
                        isCurrentUser: true,
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FullLeaderboardScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              elevation: 5,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            child: const Text('View Full Leaderboard'), // More descriptive text
          ),
        ),
      ],
    ),
  );
}

// This helper widget for a single leaderboard item is defined separately
Widget _buildLeaderboardItem(int rank, String name, String time, {bool isCurrentUser = false}) {
  final bool isTopThree = rank <= 3; // Infer top three status locally

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
    decoration: BoxDecoration(
      color: isCurrentUser
          ? Colors.yellow.withOpacity(0.15) // Subtle highlight for current user
          : (isTopThree ? Colors.blueGrey[700]?.withOpacity(0.3) : Colors.transparent), // Subtle highlight for top 3
      borderRadius: BorderRadius.circular(8.0),
      border: isCurrentUser ? Border.all(color: Colors.yellowAccent, width: 1.5) : null, // Border for current user
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text('$rank',
                style: TextStyle(
                    color: isCurrentUser ? Colors.yellowAccent : (isTopThree ? Colors.amber : Colors.white),
                    fontWeight: isCurrentUser || isTopThree ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16)),
            if (isTopThree) ...[ // Add trophy icon for top 3
              const SizedBox(width: 5),
              Icon(Icons.emoji_events, color: Colors.amber, size: 18),
            ],
            const SizedBox(width: 10),
            Text(name,
                style: TextStyle(
                    color: isCurrentUser ? Colors.yellowAccent : Colors.white,
                    fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16)),
          ],
        ),
        Text(time,
            style: TextStyle(
                color: isCurrentUser ? Colors.yellowAccent : Colors.white,
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                fontSize: 16)),
      ],
    ),
  );
}
Widget _buildAnalytics() {
  return Container( // Wrap in a container for consistent padding and background
    padding: const EdgeInsets.all(16.0),
    decoration: BoxDecoration(
      color: Colors.blueGrey[900]?.withOpacity(0.9), // Consistent dark background
      borderRadius: BorderRadius.circular(15.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          spreadRadius: 2,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Image.asset(
          'assets/analytics.png', // Ensure this path is correct and asset is added to pubspec.yaml
          height: 60, // Slightly larger logo
        ),
        const SizedBox(width: 15), // Increased spacing
        Expanded(
          child: ElevatedButton.icon( // Changed to ElevatedButton.icon for an icon
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsScreen(), // Navigate to your AI screen
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent, // A distinctive blue for AI interaction
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              elevation: 5,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.psychology_outlined, color: Colors.white), // AI/Brain icon
            label: const Text('View Analytics'),
          ),
        ),
      ],
    ),
  );
}
}