// lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../services/database_helper.dart'; // Your DatabaseHelper
import '../models/gym_session.dart'; // Your GymSession model
import '../models/workout.dart'; // NEW: Import your Workout model
import 'dart:convert'; // For JSON encoding/decoding
import 'package:http/http.dart' as http; // For making HTTP requests to Gemini API


class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserUid;

  @override
  void initState() {
    super.initState();
    _currentUserUid = _auth.currentUser?.uid;
    if (_currentUserUid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in.')),
        );
      });
    }
  }

  // --- Utility Functions for Date Calculation ---

  // Gets the start of the current week (Monday)
  DateTime _getStartOfWeek(DateTime date) {
    final int daysToSubtract = date.weekday - 1; // Subtract 0 for Monday, 1 for Tuesday, etc.
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysToSubtract));
  }

  // Gets the end of the current week (Sunday)
  DateTime _getEndOfWeek(DateTime date) {
    final DateTime startOfWeek = _getStartOfWeek(date);
    return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day)
        .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59)); // End of Sunday
  }

  // --- Data Fetching and Processing ---

  Future<Map<int, double>> _getWeeklyGymTime() async {
    if (_currentUserUid == null) {
      return {}; // Return empty if no user
    }

    final DateTime now = DateTime.now();
    final DateTime startOfWeek = _getStartOfWeek(now);
    final DateTime endOfWeek = _getEndOfWeek(now);

    print('Fetching gym sessions from: $startOfWeek to $endOfWeek');

    final List<GymSession> sessions = await _dbHelper.getGymSessionsForDateRange(
      _currentUserUid!,
      startOfWeek,
      endOfWeek,
    );

    print('Fetched ${sessions.length} sessions for the week.');

    // Initialize map for daily durations (dayOfWeek (1-7) -> totalDurationInMinutes)
    Map<int, double> dailyDurations = {
      1: 0.0, // Monday
      2: 0.0, // Tuesday
      3: 0.0, // Wednesday
      4: 0.0, // Thursday
      5: 0.0, // Friday
      6: 0.0, // Saturday
      7: 0.0, // Sunday
    };

    for (var session in sessions) {
      dailyDurations[session.startTime.weekday] =
          (dailyDurations[session.startTime.weekday] ?? 0.0) + (session.duration / 60.0); // Convert seconds to minutes
    }

    return dailyDurations;
  }

  // --- Calorie Estimation Logic ---
  Future<void> _showCalorieEstimationDialog() async {
    if (_currentUserUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to estimate calories.')),
      );
      return;
    }

    final TextEditingController _weightController = TextEditingController();

    // Define the date range for the current week
    final DateTime now = DateTime.now();
    final DateTime startOfWeek = _getStartOfWeek(now);
    final DateTime endOfWeek = _getEndOfWeek(now);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gathering workout data for the week...')),
    );

    // Fetch BOTH GymSessions and Workouts for the current week
    List<GymSession> sessionsForCurrentWeek = [];
    List<Workout> workoutsForCurrentWeek = [];
    double totalDurationMinutes = 0.0;

    try {
      sessionsForCurrentWeek = await _dbHelper.getGymSessionsForDateRange(
        _currentUserUid!,
        startOfWeek,
        endOfWeek,
      );
      workoutsForCurrentWeek = await _dbHelper.getWorkoutsForDateRange(
        _currentUserUid!,
        startOfWeek,
        endOfWeek,
      );

      totalDurationMinutes = sessionsForCurrentWeek.fold(0.0, (sum, session) => sum + session.duration / 60.0);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching workout data: ${e.toString()}')),
        );
      }
      return;
    } finally {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }

    if (sessionsForCurrentWeek.isEmpty && workoutsForCurrentWeek.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No gym sessions or workouts logged for this week for estimation.')),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Estimate Weekly Calories Burned'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please provide your current body weight to estimate calories burned this week:'),
                const SizedBox(height: 16),
                TextField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Your Body Weight (kg)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Total workout duration this week: ${totalDurationMinutes.toStringAsFixed(0)} minutes'),
                if (workoutsForCurrentWeek.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Found ${workoutsForCurrentWeek.length} individual workout entries.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // Close input dialog
                
                final double? userWeightKg = double.tryParse(_weightController.text);

                if (userWeightKg == null || userWeightKg <= 0) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid positive number for your body weight.')),
                    );
                  }
                  return;
                }

                // Pass all fetched workouts (not just sessions)
                _estimateCalories(workoutsForCurrentWeek, userWeightKg, totalDurationMinutes);
              },
              child: const Text('Estimate'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _estimateCalories(List<Workout> workouts, double userWeightKg, double totalDurationMinutes) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Estimating calories... This might take a moment.'), duration: Duration(seconds: 30)),
    );

    String prompt = "As an expert fitness and calorie expenditure calculator, estimate the total calories burned for the following workout activities for an individual weighing ${userWeightKg.toStringAsFixed(1)} kg.\n";
    prompt += "The total combined duration of all these workout sessions over the specified week was approximately ${totalDurationMinutes.toStringAsFixed(0)} minutes. The activities performed were:\n";

    if (workouts.isEmpty) {
      prompt += "- No specific workout activities recorded.\n";
    } else {
      for (var workout in workouts) {
        prompt += "   - Exercise: ${workout.name} (Category: ${workout.category}, Difficulty: ${workout.difficulty}) with ${workout.sets} sets of ${workout.reps} reps";
        if (workout.weight != null && workout.weight! > 0) {
          prompt += " at ${workout.weight!.toStringAsFixed(1)} kg";
        }
        prompt += ".\n";
      }
    }
    prompt += "\nProvide ONLY the estimated total calories in a JSON format like this: {\"estimated_calories_kcal\": \"VALUE_IN_KCAL\"}.";
    prompt += " Do not include any extra text or formatting outside of the JSON. The calorie value should be a numeric string, e.g., \"350.5\", or \"N/A\" if not estimable.";
    prompt += " Ensure the response is always valid JSON.";


    try {
      const apiKey = "YOUR_GEMINI_API_KEY"; // Replace with your actual Gemini API Key
      if (apiKey.isEmpty || apiKey == "YOUR_GEMINI_API_KEY") {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gemini API Key is not set. Please add your key to analytics_screen.dart.')),
          );
        }
        return;
      }
      
      const apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey';

      final chatHistory = [
        {"role": "user", "parts": [{"text": prompt}]}
      ];

      final payload = {
        "contents": chatHistory,
        "generationConfig": {
            "responseMimeType": "application/json",
            "responseSchema": {
                "type": "OBJECT",
                "properties": {
                    "estimated_calories_kcal": { "type": "STRING" }
                },
                "propertyOrdering": ["estimated_calories_kcal"]
            }
        }
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide loading indicator

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['candidates'] != null && responseData['candidates'].isNotEmpty) {
          final String jsonString = responseData['candidates'][0]['content']['parts'][0]['text'];
          // Ensure the JSON string is properly parsed. LLM can sometimes add markdown.
          String cleanJsonString = jsonString.startsWith('```json') && jsonString.endsWith('```')
              ? jsonString.substring(7, jsonString.length - 3).trim()
              : jsonString.trim();

          final Map<String, dynamic> result = json.decode(cleanJsonString);
          final String estimatedCalories = result['estimated_calories_kcal'];

          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Weekly Calorie Estimation'),
                content: Text('Based on your workouts this week and a body weight of ${userWeightKg.toStringAsFixed(1)} kg, you are estimated to have burned approximately $estimatedCalories kcal.'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Okay'),
                  ),
                ],
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('AI did not provide a valid estimation. Try again or check details.')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to get estimation: ${response.statusCode} ${response.body}')),
          );
        }
        print('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred during estimation: $e')),
        );
      }
      print('Network/Parsing Error: $e');
    }
  }

  // --- Build the Chart ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Set Scaffold background to black
      appBar: AppBar(
        title: const Text('Weekly Gym Time', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white), // Ensures back button is white
        actions: [
          // Calorie Estimation Button
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white), // Changed to white
            tooltip: 'Estimate Calories Burned This Week',
            onPressed: _showCalorieEstimationDialog,
          ),
        ],
      ),
      body: _currentUserUid == null
          ? const Center(child: Text('Please log in to view analytics.', style: TextStyle(color: Colors.white)))
          : Container(
              // The gradient is still here, but now the Scaffold's black background handles the 'empty' areas.
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.black87], // Black gradient background
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: FutureBuilder<Map<int, double>>(
                future: _getWeeklyGymTime(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  } else if (snapshot.hasError) {
                    print('Error fetching data: ${snapshot.error}');
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No gym sessions recorded for this week.', style: TextStyle(color: Colors.white)));
                  } else {
                    final Map<int, double> dailyDurations = snapshot.data!;
                    double maxY = dailyDurations.values.isEmpty ? 60.0 : dailyDurations.values.reduce((a, b) => a > b ? a : b);
                    if (maxY < 60) maxY = 60.0; // Ensure Y-axis at least shows 60 minutes
                    maxY = (maxY / 30).ceil() * 30.0; // Round up to nearest 30 for Y-axis intervals

                    return SingleChildScrollView( // Added SingleChildScrollView to prevent overflow
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Total Gym Time This Week (${DateFormat('MMM d').format(_getStartOfWeek(DateTime.now()))} - ${DateFormat('MMM d').format(_getEndOfWeek(DateTime.now()))})',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 250.0, // <-- Set a fixed height here (e.g., 250 pixels)
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: maxY,
                                  barTouchData: BarTouchData(
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                        final String weekdayName = DateFormat('EEE').format(DateTime(2023, 1, 1).add(Duration(days: group.x.toInt() - 1)));
                                        return BarTooltipItem(
                                          '$weekdayName\n',
                                          const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          children: <TextSpan>[
                                            TextSpan(
                                              text: '${rod.toY.toInt()} min',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: getBottomTitles,
                                        reservedSize: 42,
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        getTitlesWidget: getLeftTitles,
                                      ),
                                    ),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(
                                    show: false,
                                  ),
                                  barGroups: dailyDurations.entries.map((entry) {
                                    return BarChartGroupData(
                                      x: entry.key, // Weekday as int (1 for Mon, 7 for Sun)
                                      barRods: [
                                        BarChartRodData(
                                          toY: entry.value, // Duration in minutes
                                          color: Colors.yellow, // Changed to yellow
                                          width: 22,
                                          borderRadius: const BorderRadius.all(Radius.circular(6)),
                                          // isRound: true, // For round top
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                  gridData: FlGridData(
                                    show: true,
                                    drawHorizontalLine: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (value) {
                                      return const FlLine(
                                        color: Colors.white38, // Grid lines white
                                        strokeWidth: 1,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30), // Spacing for other analytics
                            // Your existing Workout Summary Card
                            Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              color: Colors.black54, // Card background color
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Workout Summary',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    const SizedBox(height: 10),
                                    FutureBuilder<List<GymSession>>(
                                      future: _dbHelper.getGymSessionsForDateRange(
                                          _currentUserUid!,
                                          DateTime.now().subtract(const Duration(days: 30)),
                                          DateTime.now()),
                                      builder: (context, sessionSnapshot) {
                                        if (sessionSnapshot.connectionState == ConnectionState.waiting) {
                                          return const CircularProgressIndicator(color: Colors.white);
                                        }
                                        if (sessionSnapshot.hasError) {
                                          return Text('Error: ${sessionSnapshot.error}', style: const TextStyle(color: Colors.white));
                                        }
                                        final totalSessionsLast30Days = sessionSnapshot.data?.length ?? 0;
                                        final totalDurationLast30Days = sessionSnapshot.data?.fold(0, (sum, session) => sum + session.duration) ?? 0; 
                                        final avgDurationPerSession = totalSessionsLast30Days > 0
                                            ? (totalDurationLast30Days / totalSessionsLast30Days / 60).toStringAsFixed(1)
                                            : '0.0';

                                        return Column(
                                          children: [
                                            Text('Sessions in last 30 days: $totalSessionsLast30Days', style: const TextStyle(color: Colors.white70)),
                                            Text('Avg. duration per session: $avgDurationPerSession min', style: const TextStyle(color: Colors.white70)),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // New Text widget at the bottom
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16.0), // Add some bottom padding
                              child: Text(
                                'More widgets coming in future updates!',
                                style: TextStyle(fontSize: 16, color: Colors.white70, fontStyle: FontStyle.italic),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
    );
  }

  Widget getBottomTitles(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.white, // Changed to white
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    String text;
    switch (value.toInt()) {
      case 1:
        text = 'Mon';
        break;
      case 2:
        text = 'Tue';
        break;
      case 3:
        text = 'Wed';
        break;
      case 4:
        text = 'Thu';
        break;
      case 5:
        text = 'Fri';
        break;
      case 6:
        text = 'Sat';
        break;
      case 7:
        text = 'Sun';
        break;
      default:
        text = '';
        break;
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 10,
      child: Text(text, style: style),
    );
  }

  Widget getLeftTitles(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.white, // Changed to white
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    String text;
    if (value.toInt() % 30 == 0) { // Show labels every 30 minutes
      text = '${value.toInt()} min';
    } else {
      return Container(); // Don't show for other values
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 10,
      child: Text(text, style: style),
    );
  }
}