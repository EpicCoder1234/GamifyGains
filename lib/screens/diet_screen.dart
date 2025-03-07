// diet_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';
import '../models/diet_plan.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({Key? key}) : super(key: key);

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  final dbHelper = DatabaseHelper();
  List<DietPlan> diets = [];
  String _selectedDay = DateFormat('EEEE').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadDiets(_selectedDay);
  }

  Future<void> _loadDiets(String day) async {
    diets = await dbHelper.getDiets(day);
    setState(() {});
  }

  Future<void> _addDiet() async {
    showDialog(
      context: context,
      builder: (context) => _DietDialog(
        onSave: (newDiet) async {
          await dbHelper.insertDiet(newDiet);
          await _loadDiets(_selectedDay);
        },
        selectedDay: _selectedDay,
      ),
    );
  }

  Future<void> _updateDiet(DietPlan diet) async {
    showDialog(
      context: context,
      builder: (context) => _DietDialog(
        diet: diet,
        onSave: (updatedDiet) async {
          await dbHelper.updateDiet(updatedDiet);
          await _loadDiets(_selectedDay);
        },
        selectedDay: _selectedDay,
      ),
    );
  }

  Future<void> _deleteDiet(String id) async {
    await dbHelper.deleteDiet(id);
    await _loadDiets(_selectedDay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diets'),
        actions: [
          DropdownButton<String>(
            value: _selectedDay,
            icon: const Icon(Icons.calendar_today),
            onChanged: (String? newValue) {
              setState(() {
                _selectedDay = newValue!;
                _loadDiets(_selectedDay);
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
        onPressed: _addDiet,
        child: const Icon(Icons.add),
      ),
      body: diets.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : diets.isEmpty
              ? const Center(child: Text('No diets added yet.'))
              : ListView.builder(
                  itemCount: diets.length,
                  itemBuilder: (context, index) {
                    final diet = diets[index];
                    return ListTile(
                      title: Text(diet.plan),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _updateDiet(diet),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            onPressed: () => _deleteDiet(diet.id),
                            icon: const Icon(Icons.delete),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _DietDialog extends StatefulWidget {
  final DietPlan? diet;
  final Function(DietPlan) onSave;
  final String selectedDay;

  const _DietDialog({
    Key? key,
    this.diet,
    required this.onSave,
    required this.selectedDay,
  }) : super(key: key);

  @override
  State<_DietDialog> createState() => _DietDialogState();
}

class _DietDialogState extends State<_DietDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _planController;
  late String _selectedDay;

  @override
  void initState() {
    super.initState();
    _planController = TextEditingController(text: widget.diet?.plan ?? '');
    _selectedDay = widget.selectedDay;
  }

  @override
  void dispose() {
    _planController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.diet == null ? 'Add Diet' : 'Edit Diet'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _planController,
              decoration: const InputDecoration(labelText: 'Plan'),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a diet plan';
                }
                return null;
              },
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
              final diet = DietPlan(
                id: widget.diet?.id ?? const Uuid().v4(),
                plan: _planController.text,
                day: _selectedDay,
              );
              widget.onSave(diet);
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}