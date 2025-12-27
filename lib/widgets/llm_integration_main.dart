import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User; // For current user UID
import '../services/database_helper.dart'; 
import '../services/gemini_api.dart';
import '../models/user.dart'; 
import '../models/workout.dart'; 
import '../models/diet_plan.dart'; 
import 'package:intl/intl.dart'; // For formatting current day

class LLMIntegrationScreen extends StatefulWidget {
  final String selectedDay; 
  const LLMIntegrationScreen({Key? key, required this.selectedDay})
      : super(key: key);

  @override
  State<LLMIntegrationScreen> createState() => _LLMIntegrationScreenState();
}

class _LLMIntegrationScreenState extends State<LLMIntegrationScreen> {
  late final GenerativeModel _model;
  // Make _chat nullable so we can check if it's initialized without LateInitializationError
  ChatSession? _chat; 
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode(debugLabel: 'TextField');
  bool _loading = true; // Start loading as true

  String? _currentUserUid;
  User? _currentUser;
  List<Workout>? _todayWorkouts;
  DietPlan? _todayDietPlan;
  final DatabaseHelper _dbHelper = DatabaseHelper(); 

  @override
  void initState() {
    super.initState();
    // Initialize the model here, but the chat session starts later with context
    _model = GenerativeModel(
      model: 'gemini-2.5-flash', // Using 1.5-flash which supports system instructions well
      apiKey: geminiAPIkey, 
    );

    _loadUserDataAndInitializeChat();
  }

  Future<void> _loadUserDataAndInitializeChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserUid = user.uid;
      
      try {
        _currentUser = await _dbHelper.getUser(_currentUserUid!);
      } catch (e) {
        print("Error fetching user profile: $e");
      }

      try {
        // Fetch today's workouts
        // Note: Using 'first' on a stream takes the first emitted value.
        // Ensure your streams emit at least one value (e.g., empty list) even if no data.
        _todayWorkouts = await _dbHelper.getWorkoutsStream(_currentUserUid!, DateFormat('EEEE').format(DateTime.now())).first;
      } catch (e) {
        print("Error fetching workouts: $e");
        _todayWorkouts = [];
      }

      try {
        // Fetch today's diet plan
        _todayDietPlan = await _dbHelper.getDietPlanStream(_currentUserUid!, DateFormat('EEEE').format(DateTime.now())).first;
      } catch (e) {
        print("Error fetching diet plan: $e");
        _todayDietPlan = null;
      }

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

      // Let's re-initialize model with system instruction for cleaner separation
      final modelWithSystemInstruction = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: geminiAPIkey,
          systemInstruction: Content.system(initialContext),
      );

      _chat = modelWithSystemInstruction.startChat(
        history: [], // History starts empty, context is in system instruction
      );
      
      print('AI Chat initialized with user context.');
    } else {
      if (mounted) {
        _showError('User not logged in. Please log in to use the AI assistant.');
        // Don't pop immediately, show the error first
        Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.of(context).pushReplacementNamed('/auth');
        });
      }
    }
    
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }


  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCirc,
          );
        }
      },
    );
  }

  Future<void> _sendChatMessage(String message) async {
    if (message.trim().isEmpty) {
      return;
    }

    if (_currentUserUid == null) {
      _showError('User data not loaded. Please ensure you are logged in.');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // Use _chat! since we know it's initialized if _loading is false and we are sending
      final response = await _chat!.sendMessage(Content.text(message));
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
      _scrollDown(); 
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
    // Correctly check if loading OR chat is not yet initialized
    if (_loading || _chat == null) { 
        return Scaffold(
            appBar: AppBar(
                title: const Text('AI Gym Assistant', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            body: const Center(child: CircularProgressIndicator(color: Colors.white)),
        );
    }

    // Now safe to access history because we returned early if _chat was null
    final history = _chat!.history.toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Gym Assistant', 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ), 
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white), 
        foregroundColor: Colors.white
      ),
      backgroundColor: Colors.black, // Ensure entire background is black
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
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
                      style: const TextStyle(color: Colors.white),
                      autofocus: true,
                      focusNode: _textFieldFocus,
                      decoration: textFieldDecoration(context, 'Ask anything...'),
                      controller: _textController,
                      onSubmitted: (String value) {
                        _sendChatMessage(value);
                      },
                      enabled: !_loading, 
                    ),
                  ),
                  const SizedBox.square(dimension: 15),
                  if (!_loading) 
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
                    const SizedBox(
                        width: 24, 
                        height: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    ), 
                ],
              ),
            ),
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
                h1: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                h2: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                h3: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
                listBullet: TextStyle(color: textColor),
                blockSpacing: 10.0,
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
      enabledBorder: OutlineInputBorder( // Explicitly set enabled border color
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: const BorderSide(color: Colors.white54),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
    );