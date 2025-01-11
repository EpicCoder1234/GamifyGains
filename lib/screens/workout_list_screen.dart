import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';
import '../models/workout.dart';
import 'package:intl/intl.dart';

class WorkoutListScreen extends StatefulWidget {
  const WorkoutListScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends State<WorkoutListScreen> {
  final dbHelper = DatabaseHelper();
  List<Workout> workouts = [];
  String _selectedDay = DateFormat('EEEE').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadWorkouts(_selectedDay);
  }

  Future<void> _loadWorkouts(String day) async {
    workouts = await dbHelper.getWorkouts(day);
    setState(() {});
  }

  Future<void> _addWorkout() async {
    showDialog(
      context: context,
      builder: (context) => _WorkoutDialog(
        onSave: (newWorkout) async {
          await dbHelper.insertWorkout(newWorkout);
          _loadWorkouts(_selectedDay);
        },
        selectedDay: _selectedDay,
      ),
    );
  }

  Future<void> _updateWorkout(Workout workout) async {
    showDialog(
      context: context,
      builder: (context) => _WorkoutDialog(
        workout: workout,
        onSave: (updatedWorkout) async {
          await dbHelper.updateWorkout(updatedWorkout);
          _loadWorkouts(_selectedDay);
        },
        selectedDay: _selectedDay,
      ),
    );
  }

  Future<void> _deleteWorkout(String id) async {
    await dbHelper.deleteWorkout(id);
    _loadWorkouts(_selectedDay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        actions: [
          DropdownButton<String>(
            value: _selectedDay,
            icon: const Icon(Icons.calendar_today),
            onChanged: (String? newValue) {
              setState(() {
                _selectedDay = newValue!;
                _loadWorkouts(_selectedDay);
              });
            },
            items: <String>[
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday'
            ].map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addWorkout,
        child: const Icon(Icons.add),
      ),
      body: workouts.isEmpty
          ? const Center(child: Text('No workouts added yet.'))
          : ListView.builder(
              itemCount: workouts.length,
              itemBuilder: (context, index) {
                final workout = workouts[index];
                return ListTile(
                  title: Text(workout.name),
                  subtitle: Text(
                      'Sets: ${workout.sets}, Reps: ${workout.reps}, Weight: ${workout.weight ?? 'N/A'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          onPressed: () => _updateWorkout(workout),
                          icon: const Icon(Icons.edit)),
                      IconButton(
                          onPressed: () => _deleteWorkout(workout.id),
                          icon: const Icon(Icons.delete)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _WorkoutDialog extends StatefulWidget {
  final Workout? workout;
  final Function(Workout) onSave;
  final String selectedDay;

  const _WorkoutDialog(
      {Key? key, this.workout, required this.onSave, required this.selectedDay})
      : super(key: key);

  @override
  State<_WorkoutDialog> createState() => _WorkoutDialogState();
}

class _WorkoutDialogState extends State<_WorkoutDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _setsController;
  late TextEditingController _repsController;
  late TextEditingController _weightController;
  late String _selectedDay;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.workout?.name ?? '');
    _setsController =
        TextEditingController(text: widget.workout?.sets.toString() ?? '');
    _repsController =
        TextEditingController(text: widget.workout?.reps.toString() ?? '');
    _weightController =
        TextEditingController(text: widget.workout?.weight?.toString() ?? '');
    _selectedDay = widget.selectedDay;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.workout == null ? 'Add Workout' : 'Edit Workout'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _setsController,
              decoration: const InputDecoration(labelText: 'Sets'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter sets';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _repsController,
              decoration: const InputDecoration(labelText: 'Reps'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter reps';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: 'Weight (optional)'),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              value: _selectedDay,
              onChanged: (newValue) {
                setState(() {
                  _selectedDay = newValue!;
                });
              },
              items: <String>[
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
                'Sunday'
              ].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              decoration: const InputDecoration(labelText: 'Day'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final workout = Workout(
                id: widget.workout?.id ?? const Uuid().v4(),
                name: _nameController.text,
                sets: int.parse(_setsController.text),
                reps: int.parse(_repsController.text),
                weight: _weightController.text.isNotEmpty
                    ? double.tryParse(_weightController.text)
                    : null,
                day: _selectedDay,
              );
              widget.onSave(workout);
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}