// lib/screens/exercise_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models/exercise.dart';
import '../services/database_helper.dart';
import '../models/workout.dart';
import 'package:intl/intl.dart';
import '../widgets/workout_dialog.dart';
import '../widgets/exercise_detail_bottom_chart.dart'; // Import the new bottom sheet widget

// A callback function type to return the selected/created Workout
typedef OnWorkoutSelected = void Function(Workout workout);


class ExerciseSelectionScreen extends StatefulWidget {
  // currentSelectedDay: The specific calendar date (yyyy-MM-dd) chosen from WorkoutListScreen (e.g., today's date).
  // selectedDayOfWeek: The repeating day name (e.g., "Thursday") chosen from WorkoutListScreen.
  final String currentSelectedDay;
  final String selectedDayOfWeek; // NEW: Parameter for the repeating day name
  final String? currentUserUid;

  const ExerciseSelectionScreen({
    Key? key,
    required this.currentSelectedDay,
    required this.selectedDayOfWeek, // Required
    required this.currentUserUid,
  }) : super(key: key);

  @override
  State<ExerciseSelectionScreen> createState() => _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends State<ExerciseSelectionScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String _selectedCategory = 'All';
  List<Exercise> _commonExercises = [];
  List<Exercise> _userExercises = [];
  List<String> _categories = ['All', 'Create New Exercise'];
  bool _isLoadingCommonExercises = true;
  bool _isLoadingUserExercises = true;

  @override
  void initState() {
    super.initState();
    _fetchCategoriesAndExercises();
  }

  Future<void> _fetchCategoriesAndExercises() async {
    _dbHelper.getCommonExercisesStream().listen((exercises) {
      if (mounted) {
        setState(() {
          _commonExercises = exercises;
          _isLoadingCommonExercises = false;
          _updateCategories();
        });
      }
    }, onError: (error) {
      print("Error fetching common exercises: $error");
      if (mounted) {
        setState(() {
          _isLoadingCommonExercises = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading common exercises: ${error.toString()}')),
        );
      }
    });

    if (widget.currentUserUid != null) {
      _dbHelper.getUserExercisesStream(widget.currentUserUid!).listen((exercises) {
        if (mounted) {
          setState(() {
            _userExercises = exercises;
            _isLoadingUserExercises = false;
            _updateCategories();
          });
        }
      }, onError: (error) {
        print("Error fetching user exercises: $error");
        if (mounted) {
          setState(() {
            _isLoadingUserExercises = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading custom exercises: ${error.toString()}')),
          );
        }
      });
    } else {
      setState(() {
        _isLoadingUserExercises = false;
      });
    }
  }

  void _updateCategories() {
    List<String> combinedCategories = [];
    
    for (var e in _commonExercises) {
      if (e.category.isNotEmpty) {
        combinedCategories.add(e.category);
      }
    }
    for (var e in _userExercises) {
      if (e.category.isNotEmpty) {
        combinedCategories.add(e.category);
      }
    }

    List<String> uniqueSortedCategories = combinedCategories.toSet().toList()..sort();

    _categories = ['All'] + uniqueSortedCategories + ['Create New Exercise'];

    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = 'All';
    }
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  void _showCreateNewExerciseDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildCreateNewExerciseForm(dialogContext),
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedCategory = 'All';
        });
      }
    });
  }

  // MODIFIED: This method now first shows ExerciseDetailBottomSheet
  // then, if confirmed, it calls _showWorkoutDetailsDialog
  void _handleExerciseSelection(Exercise selectedExercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return ExerciseDetailBottomSheet(
          exercise: selectedExercise,
          onConfirmExercise: (confirmedExercise) {
            // This callback is triggered when "Confirm Exercise" is pressed
            // within the bottom sheet. Now, open the WorkoutDialog.
            // Pop the bottom sheet first to ensure context validity
            Navigator.of(sheetContext).pop(); 
            _showWorkoutDetailsDialog(context, confirmedExercise); // Use the original screen context
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    List<Exercise> displayedExercises = [];
    if (_selectedCategory == 'All') {
      displayedExercises = List.from(_commonExercises + _userExercises);
    } else if (_selectedCategory != 'Create New Exercise') {
      displayedExercises = List.from((_commonExercises + _userExercises)
          .where((e) => e.category == _selectedCategory)
          .toList());
    }

    displayedExercises.sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: Text('Select Exercise for ${widget.selectedDayOfWeek}'), // Display day of week
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              showSearch<Exercise?>(
                context: context,
                delegate: ExerciseSearchDelegate(
                  _commonExercises + _userExercises,
                  (selectedExercise) {
                    _handleExerciseSelection(selectedExercise);
                  },
                  _launchURL,
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/barbell_background.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.darken,
            ),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple[800]!.withOpacity(0.9), Colors.blueGrey[900]!.withOpacity(0.9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Filter by Category',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.category, color: Colors.white70),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  dropdownColor: Colors.blueGrey[900],
                  iconEnabledColor: Colors.white,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                        if (_selectedCategory == 'Create New Exercise') {
                          _showCreateNewExerciseDialog();
                        }
                      });
                    }
                  },
                  items: _categories.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(
                          color: value == 'Create New Exercise' ? Colors.greenAccent : Colors.white,
                          fontWeight: value == 'Create New Exercise' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Expanded(
              child: (_isLoadingCommonExercises || _isLoadingUserExercises)
                  ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
                  : displayedExercises.isEmpty && _selectedCategory != 'Create New Exercise'
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fitness_center_outlined, size: 60, color: Colors.grey[400]),
                              const SizedBox(height: 20),
                              Text(
                                _selectedCategory == 'All'
                                    ? 'No exercises found. Add your first custom exercise!'
                                    : 'No exercises found in this category.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: 20),
                              if (_selectedCategory == 'All')
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedCategory = 'Create New Exercise';
                                    });
                                    _showCreateNewExerciseDialog();
                                  },
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                                  label: const Text('Create New Exercise', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: displayedExercises.length,
                          itemBuilder: (context, index) {
                            final exercise = displayedExercises[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                              elevation: 6,
                              color: Colors.white.withOpacity(0.95),
                              child: ListTile(
                                onTap: () => _handleExerciseSelection(exercise),
                                leading: Icon(Icons.fitness_center_outlined, color: Colors.deepPurple[400]),
                                title: Text(
                                  exercise.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                ),
                                subtitle: Text(
                                  'Category: ${exercise.category}\nMuscles: ${exercise.targetMuscles.join(', ')}',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                trailing: (exercise.videoLink != null && exercise.videoLink!.isNotEmpty)
                                    ? IconButton(
                                        icon: const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 30),
                                        onPressed: () {
                                          _launchURL(exercise.videoLink!);
                                        },
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateNewExerciseForm(BuildContext dialogContext) {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController categoryController = TextEditingController();
    final TextEditingController musclesController = TextEditingController();
    final TextEditingController videoLinkController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController equipmentController = TextEditingController();
    final TextEditingController difficultyController = TextEditingController();

    const OutlineInputBorder outlineInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12.0)),
      borderSide: BorderSide(color: Colors.deepPurple, width: 1.5),
    );

    const OutlineInputBorder focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12.0)),
      borderSide: BorderSide(color: Colors.lightBlueAccent, width: 2.0),
    );

    const TextStyle labelHintStyle = TextStyle(color: Colors.grey, fontSize: 16);
    const TextStyle inputTextStyle = TextStyle(color: Colors.black87, fontSize: 17);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.0),
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade700, Colors.blueAccent.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              spreadRadius: 3,
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Create Custom Exercise',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Divider(height: 30, thickness: 1.5, color: Colors.white54),
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Exercise Name',
                  labelStyle: labelHintStyle.copyWith(color: Colors.white70),
                  prefixIcon: const Icon(Icons.fitness_center, color: Colors.white70),
                  border: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                  enabledBorder: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                  focusedBorder: focusedInputBorder.copyWith(borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2.0)),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                ),
                style: inputTextStyle.copyWith(color: Colors.white),
                validator: (value) => value!.isEmpty ? 'Please enter exercise name' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  labelStyle: labelHintStyle.copyWith(color: Colors.white70),
                  prefixIcon: const Icon(Icons.description, color: Colors.white70),
                  border: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                  enabledBorder: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                  focusedBorder: focusedInputBorder.copyWith(borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2.0)),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                ),
                style: inputTextStyle.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: categoryController,
                decoration: InputDecoration(
                  labelText: 'Category (e.g., Chest, Legs, Cardio)',
                  labelStyle: labelHintStyle.copyWith(color: Colors.white70),
                  prefixIcon: const Icon(Icons.category, color: Colors.white70),
                  border: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                  enabledBorder: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                  focusedBorder: focusedInputBorder.copyWith(borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2.0)),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                ),
                style: inputTextStyle.copyWith(color: Colors.white),
                validator: (value) => value!.isEmpty ? 'Please enter a category' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: musclesController,
                decoration: InputDecoration(
                  labelText: 'Target Muscles (comma-separated, e.g., Biceps, Triceps)',
                  labelStyle: labelHintStyle.copyWith(color: Colors.white70),
                  prefixIcon: const Icon(Icons.accessibility_new, color: Colors.white70),
                  border: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                  enabledBorder: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                  focusedBorder: focusedInputBorder.copyWith(borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2.0)),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                ),
                style: inputTextStyle.copyWith(color: Colors.white),
                validator: (value) => value!.isEmpty ? 'Please enter target muscles' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: equipmentController,
                decoration: InputDecoration(
                  labelText: 'Equipment (comma-separated, e.g., Dumbbells, Bench)',
                  labelStyle: labelHintStyle.copyWith(color: Colors.white70),
                  prefixIcon: const Icon(Icons.hardware, color: Colors.white70),
                  border: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                  enabledBorder: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                  focusedBorder: focusedInputBorder.copyWith(borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2.0)),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                ),
                style: inputTextStyle.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: difficultyController,
                decoration: InputDecoration(
                  labelText: 'Difficulty (e.g., Beginner, Intermediate, Advanced)',
                  labelStyle: labelHintStyle.copyWith(color: Colors.white70),
                  prefixIcon: const Icon(Icons.star, color: Colors.white70),
                  border: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                  enabledBorder: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                  focusedBorder: focusedInputBorder.copyWith(borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2.0)),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                ),
                style: inputTextStyle.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: videoLinkController,
                decoration: InputDecoration(
                  labelText: 'Video Link (Optional, YouTube URL)',
                  labelStyle: labelHintStyle.copyWith(color: Colors.white70),
                  prefixIcon: const Icon(Icons.link, color: Colors.white70),
                  border: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                  enabledBorder: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                  focusedBorder: focusedInputBorder.copyWith(borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2.0)),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                ),
                style: inputTextStyle.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final newExercise = Exercise(
                      id: const Uuid().v4(),
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim().isNotEmpty ? descriptionController.text.trim() : null,
                      category: categoryController.text.trim(),
                      targetMuscles: musclesController.text.trim().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                      equipment: equipmentController.text.trim().isNotEmpty ? equipmentController.text.trim().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : null,
                      difficulty: difficultyController.text.trim().isNotEmpty ? difficultyController.text.trim() : null,
                      videoLink: videoLinkController.text.trim().isNotEmpty ? videoLinkController.text.trim() : null,
                    );
                    if (widget.currentUserUid != null) {
                      await _dbHelper.saveUserExercise(widget.currentUserUid!, newExercise);
                      // Check if dialogContext is still mounted before showing SnackBar
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('${newExercise.name} added to your custom exercises!')),
                        );
                        Navigator.pop(dialogContext);
                      }
                    } else {
                      // Check if dialogContext is still mounted before showing SnackBar
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Please log in to save custom exercises.')),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.add_circle, color: Colors.white),
                label: const Text('Add Custom Exercise', style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MODIFIED: _showWorkoutDetailsDialog now takes the selected exercise from the bottom sheet.
  // It also implicitly uses widget.currentSelectedDay (the specific date) and widget.selectedDayOfWeek (the day name).
  void _showWorkoutDetailsDialog(BuildContext context, Exercise selectedExercise) {
    showDialog(
      context: context,
      builder: (dialogContext) => WorkoutDialog( // Renamed context to dialogContext for clarity
        uid: widget.currentUserUid!,
        specificDate: widget.currentSelectedDay, // Pass the specific date from this screen's state
        dayOfWeek: widget.selectedDayOfWeek, // Pass the day of week name from this screen's state
        exercise: selectedExercise,
        onSave: (newWorkout) async {
          await _dbHelper.saveWorkout(newWorkout);
          // Check if the dialogContext (from WorkoutDialog) is still mounted
          if (dialogContext.mounted) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(content: Text('${newWorkout.name} added to your workouts!')),
            );
            // Pop the WorkoutDialog first
            Navigator.of(dialogContext).pop(); 
            // Then pop the ExerciseSelectionScreen, ensuring its context is still valid
            if (mounted) { // Check if the ExerciseSelectionScreen is still mounted
              Navigator.of(context).pop(true);
            }
          }
        },
      ),
    );
  }
}

class ExerciseSearchDelegate extends SearchDelegate<Exercise?> {
  final List<Exercise> exercises;
  final Function(Exercise) onSelect; // This now needs to be able to show the detail sheet
  final Function(String) launchUrlCallback;

  ExerciseSearchDelegate(this.exercises, this.onSelect, this.launchUrlCallback);

  @override
  String get searchFieldLabel => 'Search exercises...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white54),
        border: InputBorder.none,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.deepPurpleAccent,
        selectionColor: Colors.deepPurple,
        selectionHandleColor: Colors.deepPurpleAccent,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final filteredExercises = exercises
        .where((exercise) =>
            exercise.name.toLowerCase().contains(query.toLowerCase()) ||
            exercise.targetMuscles.join(', ').toLowerCase().contains(query.toLowerCase()) ||
            exercise.category.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return _buildExerciseList(context, filteredExercises);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filteredExercises = exercises
        .where((exercise) =>
            exercise.name.toLowerCase().contains(query.toLowerCase()) ||
            exercise.targetMuscles.join(', ').toLowerCase().contains(query.toLowerCase()) ||
            exercise.category.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return _buildExerciseList(context, filteredExercises);
  }

  Widget _buildExerciseList(BuildContext context, List<Exercise> exercises) {
    if (exercises.isEmpty) {
      return const Center(child: Text('No matching exercises found.', style: TextStyle(color: Colors.grey)));
    }
    return Container(
      decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/barbell_background.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.darken,
            ),
          ),
        ),
      child: ListView.builder(
        itemCount: exercises.length,
        itemBuilder: (context, index) {
          final exercise = exercises[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            elevation: 4,
            color: Colors.white.withOpacity(0.95),
            child: ListTile(
              onTap: () {
                onSelect(exercise);
                close(context, null);
              },
              leading: Icon(Icons.fitness_center_outlined, color: Colors.deepPurple[400]),
              title: Text(
                exercise.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              subtitle: Text(
                'Category: ${exercise.category}\nMuscles: ${exercise.targetMuscles.join(', ')}',
                style: TextStyle(color: Colors.grey[700]),
              ),
              trailing: (exercise.videoLink != null && exercise.videoLink!.isNotEmpty)
                  ? IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 30),
                      onPressed: () {
                        launchUrlCallback(exercise.videoLink!);
                      },
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}