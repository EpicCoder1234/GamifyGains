// lib/widgets/workout_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../services/database_helper.dart';

class WorkoutDialog extends StatefulWidget {
  final String uid; // User ID
  final String specificDate; // The specific date (yyyy-MM-dd) for this workout instance
  final String dayOfWeek; // NEW: The day of the week name (e.g., "Thursday") for repeating
  final Exercise exercise;
  final Workout? existingWorkout; // Optional: for editing an existing workout
  final Function(Workout) onSave; // Callback to save the workout

  const WorkoutDialog({
    Key? key,
    required this.uid,
    required this.specificDate, // Renamed from selectedDay
    required this.dayOfWeek, // NEW
    required this.exercise,
    this.existingWorkout,
    required this.onSave,
  }) : super(key: key);

  @override
  State<WorkoutDialog> createState() => _WorkoutDialogState();
}

class _WorkoutDialogState extends State<WorkoutDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _workoutName;
  late int _sets;
  late int _reps;
  late double _weight;
  late String _notes;
  late String _selectedDifficulty;

  // Options for dropdowns
  final List<String> _difficultyOptions = ['Easy', 'Medium', 'Hard'];
  final List<int> _setOptions = List.generate(10, (index) => index + 1); // 1 to 10 sets
  final List<int> _repOptions = List.generate(20, (index) => index + 1); // 1 to 20 reps

  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingWorkout != null) {
      _workoutName = widget.existingWorkout!.name;
      _sets = widget.existingWorkout!.sets;
      _reps = widget.existingWorkout!.reps;
      _weight = widget.existingWorkout!.weight ?? 0.0;
      _notes = widget.existingWorkout!.notes ?? '';
      _selectedDifficulty = widget.existingWorkout!.difficulty;
      _weightController.text = _weight.toString();
      _notesController.text = _notes;
    } else {
      _workoutName = widget.exercise.name;
      _sets = _setOptions.first;
      _reps = _repOptions.first;
      _weight = 0.0;
      _notes = '';
      _selectedDifficulty = _difficultyOptions.contains('Medium') ? 'Medium' : _difficultyOptions.first;
      _weightController.text = '0.0';
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveWorkout() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final workout = Workout(
        id: widget.existingWorkout?.id ?? const Uuid().v4(),
        uid: widget.uid,
        name: _workoutName,
        date: widget.specificDate, // Use the specific date from parameter
        dayOfWeek: widget.dayOfWeek, // NEW: Use the day of week name from parameter
        sets: _sets,
        reps: _reps,
        weight: _weight,
        difficulty: _selectedDifficulty,
        notes: _notes.isEmpty ? null : _notes,
        timestamp: DateTime.now().toIso8601String(),
        exerciseName: widget.exercise.name,
        category: widget.exercise.category,
        exerciseId: widget.exercise.id,
      );

      widget.onSave(workout);
      // Navigator.pop(context); // Handled by the onSave callback in parent
    }
  }

  @override
  Widget build(BuildContext context) {
    const OutlineInputBorder outlineInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12.0)),
      borderSide: BorderSide(color: Colors.deepPurple, width: 1.5),
    );

    const OutlineInputBorder focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12.0)),
      borderSide: BorderSide(color: Colors.lightBlueAccent, width: 2.0),
    );

    const TextStyle labelHintStyle = TextStyle(color: Colors.white70, fontSize: 16);
    const TextStyle inputTextStyle = TextStyle(color: Colors.white, fontSize: 17);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0),
            gradient: LinearGradient(
              colors: [const Color.fromARGB(255, 234, 141, 2), const Color.fromARGB(255, 147, 50, 1)],
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
                Text(
                  widget.existingWorkout == null ? 'Add Workout for ${widget.exercise.name}' : 'Edit Workout',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  // Display both the specific date and the repeating day
                  'On ${DateFormat('EEEE, MMM d, BCE').format(DateTime.parse(widget.specificDate))} (for all ${widget.dayOfWeek}s)',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const Divider(height: 30, thickness: 1.5, color: Colors.white54),
                
                TextFormField(
                  initialValue: _workoutName,
                  decoration: InputDecoration(
                    labelText: 'Workout Name',
                    labelStyle: labelHintStyle,
                    prefixIcon: const Icon(Icons.title, color: Colors.white70),
                    border: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                    enabledBorder: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                    focusedBorder: focusedInputBorder.copyWith(borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2.0)),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                  ),
                  style: inputTextStyle,
                  validator: (value) => value!.isEmpty ? 'Please enter a workout name' : null,
                  onSaved: (value) => _workoutName = value!.trim(),
                ),
                const SizedBox(height: 15),

                _buildStyledDropdown<int>(
                  labelText: 'Sets',
                  value: _sets,
                  items: _setOptions,
                  onChanged: (newValue) {
                    setState(() {
                      _sets = newValue!;
                    });
                  },
                  icon: Icons.repeat,
                ),
                const SizedBox(height: 15),

                _buildStyledDropdown<int>(
                  labelText: 'Reps',
                  value: _reps,
                  items: _repOptions,
                  onChanged: (newValue) {
                    setState(() {
                      _reps = newValue!;
                    });
                  },
                  icon: Icons.loop,
                ),
                const SizedBox(height: 15),

                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Weight (kg/lbs)',
                    labelStyle: labelHintStyle,
                    prefixIcon: const Icon(Icons.scale, color: Colors.white70),
                    border: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                    enabledBorder: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                    focusedBorder: focusedInputBorder.copyWith(borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2.0)),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                  ),
                  style: inputTextStyle,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter weight';
                    if (double.tryParse(value) == null) return 'Please enter a valid number';
                    return null;
                  },
                  onSaved: (value) => _weight = double.parse(value!),
                ),
                const SizedBox(height: 15),

                _buildStyledDropdown<String>(
                  labelText: 'Difficulty',
                  value: _selectedDifficulty,
                  items: _difficultyOptions,
                  onChanged: (newValue) {
                    setState(() {
                      _selectedDifficulty = newValue!;
                    });
                  },
                  icon: Icons.analytics_outlined,
                ),
                const SizedBox(height: 15),

                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    labelStyle: labelHintStyle,
                    prefixIcon: const Icon(Icons.notes, color: Colors.white70),
                    alignLabelWithHint: true,
                    border: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                    enabledBorder: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                    focusedBorder: focusedInputBorder.copyWith(borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2.0)),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                  ),
                  style: inputTextStyle,
                  onSaved: (value) => _notes = value?.trim() ?? '',
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.cancel, color: Colors.white),
                        label: const Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveWorkout,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: Text(widget.existingWorkout == null ? 'Add Workout' : 'Update Workout', style: const TextStyle(color: Colors.white, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyledDropdown<T>({
    required String labelText,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required IconData icon,
  }) {
    const OutlineInputBorder outlineInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12.0)),
      borderSide: BorderSide(color: Colors.deepPurple, width: 1.5),
    );
    const OutlineInputBorder focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12.0)),
      borderSide: BorderSide(color: Colors.lightBlueAccent, width: 2.0),
    );
    const TextStyle labelHintStyle = TextStyle(color: Colors.white70, fontSize: 16);
    const TextStyle inputTextStyle = TextStyle(color: Colors.white, fontSize: 17);

    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: labelHintStyle,
        prefixIcon: Icon(icon, color: Colors.white70),
        border: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
        enabledBorder: outlineInputBorder.copyWith(borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
        focusedBorder: focusedInputBorder.copyWith(borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2.0)),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
      ),
      style: inputTextStyle,
      dropdownColor: Colors.blueGrey[900],
      iconEnabledColor: Colors.white,
      onChanged: onChanged,
      items: items.map<DropdownMenuItem<T>>((T itemValue) {
        return DropdownMenuItem<T>(
          value: itemValue,
          child: Text(
            itemValue.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
      validator: (val) {
        if (val == null) {
          return 'Please select a $labelText';
        }
        return null;
      },
    );
  }
}
