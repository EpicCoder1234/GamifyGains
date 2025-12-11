import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User; // For current user UID
import '../services/database_helper.dart'; // To fetch user data, workouts, diet
import '../models/user.dart'; // User model
import '../models/workout.dart'; // Workout model
import '../models/diet_plan.dart'; // DietPlan model
import 'package:intl/intl.dart'; // For formatting current day

class LLMIntegrationScreen extends StatefulWidget {
  final String selectedDay; // This might represent the current day from HomeScreen
  const LLMIntegrationScreen({Key? key, required this.selectedDay})
      : super(key: key);

  @override
  State<LLMIntegrationScreen> createState() => _LLMIntegrationScreenState();
}

class _LLMIntegrationScreenState extends State<LLMIntegrationScreen> {
  late final GenerativeModel _model;
  late ChatSession _chat; // Made non-final as it's initialized async
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode(debugLabel: 'TextField');
  bool _loading = false;

  String? _currentUserUid;
  User? _currentUser;
  List<Workout>? _todayWorkouts;
  DietPlan? _todayDietPlan;
  final DatabaseHelper _dbHelper = DatabaseHelper(); // Instantiate dbHelper

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: 'AIzaSyD8FiefzYj6uoOYjVoPqClVxZXegof564Y', // Keep your API key here
    );
    // Initialize chat asynchronously after fetching user data
    _loadUserDataAndInitializeChat();
  }

  // New method to fetch user data and initialize the chat session
  Future<void> _loadUserDataAndInitializeChat() async {
    setState(() {
      _loading = true; // Show loading indicator while fetching user data
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserUid = user.uid;
      _currentUser = await _dbHelper.getUser(_currentUserUid!);

      // Corrected: Using .first to get a single snapshot from the streams
      _todayWorkouts = (await _dbHelper.getWorkoutsStream(_currentUserUid!, DateFormat('EEEE').format(DateTime.now())).first);
      _todayDietPlan = (await _dbHelper.getDietPlanStream(_currentUserUid!, DateFormat('EEEE').format(DateTime.now())).first);

      String initialContext = "You are an AI gym assistant named 'Gamify Gains AI'. Your purpose is to provide personalized fitness and health advice. Always keep the user's provided context in mind. Here is the user's current context:\n";

      if (_currentUser != null) {
        initialContext += "- Name: ${_currentUser!.name}\n";
        initialContext += "- Age: ${_currentUser!.age} years\n";
        initialContext += "- Weight: ${_currentUser!.weight} lbs\n";
        initialContext += "- Height: ${_currentUser!.height} inches\n";
        initialContext += "- Total weekly gym time: ${(_currentUser!.weeklyGymTime ?? 0)} seconds\n";
      } else {
        initialContext += "- User profile data (name, age, weight, height, weekly gym time) not found. \n";
      }

      initialContext += "- Today is ${DateFormat('EEEE').format(DateTime.now())}.\n";

      if (_todayWorkouts != null && _todayWorkouts!.isNotEmpty) {
        initialContext += "- Today's planned workouts:\n";
        for (var workout in _todayWorkouts!) {
          initialContext += "  - ${workout.name} (${workout.type}): ${workout.sets} sets, ${workout.reps} reps";
          if (workout.weight != null) {
            initialContext += ", ${workout.weight} kg";
          }
          initialContext += "\n";
        }
      } else {
        initialContext += "- No workouts planned for today.\n";
      }

      if (_todayDietPlan != null) {
        if (_todayDietPlan!.isCheatDay) {
          initialContext += "- Today is a cheat day for diet. ";
        } else {
          initialContext += "- Today's diet plan: Breakfast: ${_todayDietPlan!.breakfast}, Lunch: ${_todayDietPlan!.lunch}, Dinner: ${_todayDietPlan!.dinner}";
          if (_todayDietPlan!.hasSnack && _todayDietPlan!.snackDetails != null) {
            initialContext += ", Snack: ${_todayDietPlan!.snackDetails}.";
          } else {
            initialContext += ", No snack planned.";
          }
        }
      } else {
        initialContext += "- No diet plan set for today.";
      }
      initialContext += "\n";

      _chat = _model.startChat(
        history: [
          // Send the initial context as a model message so it guides the AI's responses
          // without being part of the user's direct conversation history.
          Content.model([TextPart(initialContext)]),
        ],
      );
      print('AI Chat initialized with user context.');
    } else {
      _showError('User not logged in. Please log in to use the AI assistant.');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
    setState(() {
      _loading = false;
    });
  }


  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCirc,
      ),
    );
  }

  Future<void> _sendChatMessage(String message) async {
    if (message.trim().isEmpty) {
      _showError('Please enter a message.');
      return;
    }

    if (_currentUserUid == null || _currentUser == null) {
      _showError('User data not loaded. Please ensure you are logged in and your profile exists.');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // Send only the user's message; the context is already in the chat history.
      final response = await _chat.sendMessage(Content.text(message));
      final text = response.text;

      if (text == null) {
        _showError('Empty response from AI.');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      _textController.clear();
      setState(() {
        _loading = false;
      });
      _scrollDown(); // Ensure scrolling happens after any message (user or model) or error
      _textFieldFocus.requestFocus();
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Something went wrong'),
          content: SingleChildScrollView(
            child: Text(message),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = _chat.history.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('AI Gym Assistant', style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),), backgroundColor: Colors.black,iconTheme: const IconThemeData(color: Colors.white), foregroundColor: Colors.white),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: _loading && history.isEmpty // Show loading indicator only if initial load and no history yet
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      itemBuilder: (context, idx) {
                        final content = history[idx];
                        final text = content.parts
                            .whereType<TextPart>()
                            .map<String>((e) => e.text)
                            .join('');
                        return MessageWidget(
                          text: text,
                          isFromUser: content.role == 'user',
                        );
                      },
                      itemCount: history.length,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: TextStyle(color: Colors.white),
                      autofocus: true,
                      focusNode: _textFieldFocus,
                      decoration:
                          textFieldDecoration(context, 'Ask anything...'),

                      controller: _textController,
                      onSubmitted: (String value) {
                        _sendChatMessage(value);
                      },
                      enabled: !_loading, // Disable input while loading
                    ),
                  ),
                  const SizedBox.square(dimension: 15),
                  if (!_loading) // Only show send button when not loading
                    IconButton(
                      onPressed: () async {
                        _sendChatMessage(_textController.text);
                      },
                      icon: Icon(
                        Icons.send,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  else
                    const CircularProgressIndicator(), // Show loading indicator instead of send button
                ],
              ),
            ),
            // Removed the ElevatedButton 'Save Diet Plan' from here as it seems out of place
            // for a general LLM assistant. If it's specifically for Diet Plan suggestions,
            // it should be in the DietScreen or conditionally rendered based on context.
            // For now, removing to simplify and align with general AI chat.
          ],
        ),
      ),
    );
  }
}

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    required this.text,
    required this.isFromUser,
  });

  final String text;
  final bool isFromUser;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isFromUser ? const Color(0xFFCC5500) : const Color(0xFF2E2E2E); // dark orange or dark gray
    final textColor = Colors.white;

    return Row(
      mainAxisAlignment:
          isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            margin: const EdgeInsets.only(bottom: 8),
            child: MarkdownBody(
              data: text,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: TextStyle(color: textColor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


InputDecoration textFieldDecoration(BuildContext context, String hintText) =>
    InputDecoration(
      filled: true,
      fillColor: Colors.grey[900], // dark text field background
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.grey),
      contentPadding: const EdgeInsets.all(15),
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: const BorderSide(color: Colors.white),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary),
      ),
    );
