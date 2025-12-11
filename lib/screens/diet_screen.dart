import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';
import '../models/diet_plan.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({Key? key}) : super(key: key);

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  final dbHelper = DatabaseHelper();
  Stream<DietPlan?>? _currentDietPlanStream;
  String _selectedDay = DateFormat('EEEE').format(DateTime.now());
  String? _currentUserUid;

  final List<String> _daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserUid();
  }

  void _loadCurrentUserUid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserUid = user.uid;
        _updateDietPlanStream();
      });
    } else {
      print('DietScreen: No user logged in.');
    }
  }

  void _updateDietPlanStream() {
    if (_currentUserUid != null) {
      _currentDietPlanStream = dbHelper.getDietPlanStream(_currentUserUid!, _selectedDay);
    } else {
      _currentDietPlanStream = null;
    }
    setState(() {});
  }

  Future<void> _showDietDialog({DietPlan? diet}) async {
    if (_currentUserUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to manage your diet plan.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _DietDialog(
        uid: _currentUserUid!,
        diet: diet,
        selectedDay: _selectedDay,
        onSave: (savedDiet) async {
          await dbHelper.saveDietPlan(savedDiet);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Allows body to go behind app bar for full background image
      appBar: AppBar(
        title: const Text(
          'Your Diet Plan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, // Make app bar transparent
        elevation: 0, // Remove shadow
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<String>(
              value: _selectedDay,
              icon: const Icon(Icons.calendar_today, color: Colors.white),
              dropdownColor: Colors.black87, // Dark dropdown background
              style: const TextStyle(color: Colors.white, fontSize: 16),
              underline: Container(), // Remove underline
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedDay = newValue;
                    _updateDietPlanStream();
                  });
                }
              },
              items: _daysOfWeek.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: const TextStyle(color: Colors.white), // Ensure text in dropdown is white
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDietDialog(diet: null),
        backgroundColor: Colors.deepOrangeAccent, // Vibrant orange for FAB
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0), // Rounded rectangular shape
        ),
        child: const Icon(Icons.add, size: 30),
      ),
      body: Container(
        // Set entire screen background to black
        color: Colors.black, // Set the background to black
        child: Center( // Center the content
          child: _currentUserUid == null
              ? const CircularProgressIndicator(color: Colors.deepOrangeAccent)
              : _currentDietPlanStream == null
                  ? const CircularProgressIndicator(color: Colors.deepOrangeAccent)
                  : StreamBuilder<DietPlan?>(
                      stream: _currentDietPlanStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator(color: Colors.deepOrangeAccent);
                        }
                        if (snapshot.hasError) {
                          print('DietStream Error: ${snapshot.error}');
                          return Center(child: Text('Error loading diet plan: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                        }

                        final DietPlan? diet = snapshot.data;

                        if (diet == null) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.restaurant_menu, size: 60, color: Colors.deepOrangeAccent),
                              const SizedBox(height: 20),
                              Text(
                                'No diet plan for $_selectedDay yet.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, color: Colors.white70),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () => _showDietDialog(diet: null),
                                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                                label: const Text('Create Diet Plan', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepOrangeAccent, // Orange button
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column( // Use Column to manage multiple sections within the scroll view
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Card(
                                  elevation: 8,
                                  color: Colors.black.withOpacity(0.7), // Darker, semi-transparent card
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Diet Plan for $_selectedDay',
                                          style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.deepOrangeAccent), // Orange title
                                        ),
                                        const Divider(height: 30, color: Colors.white38),
                                        if (diet.isCheatDay)
                                          Column(
                                            children: [
                                              const Icon(Icons.cake, size: 80, color: Colors.lightGreenAccent),
                                              const SizedBox(height: 10),
                                              const Text(
                                                'Today is a CHEAT DAY!',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(fontSize: 22, color: Colors.lightGreenAccent, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 5),
                                              const Text(
                                                'Enjoy your food, you\'ve earned it!',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(fontSize: 16, color: Colors.white70, fontStyle: FontStyle.italic),
                                              ),
                                            ],
                                          )
                                        else
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildMealRow(context, Icons.free_breakfast, 'Breakfast', diet.breakfast),
                                              _buildMealRow(context, Icons.lunch_dining, 'Lunch', diet.lunch),
                                              _buildMealRow(context, Icons.dinner_dining, 'Dinner', diet.dinner),
                                              if (diet.hasSnack)
                                                _buildMealRow(context, Icons.cookie, 'Snack', diet.snackDetails ?? 'Not specified')
                                              else
                                                const Padding(
                                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                                  child: Text(
                                                    'No snack planned.',
                                                    style: TextStyle(fontSize: 16, color: Colors.white70, fontStyle: FontStyle.italic),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        const SizedBox(height: 20),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: ElevatedButton.icon(
                                            onPressed: () => _showDietDialog(diet: diet),
                                            icon: const Icon(Icons.edit, color: Colors.white),
                                            label: const Text('Edit Plan', style: TextStyle(color: Colors.white)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.deepOrange, // Orange button
                                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
        ),
      ),
    );
  }

  Widget _buildMealRow(BuildContext context, IconData icon, String title, String details) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.deepOrangeAccent, size: 28), // Orange icons
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title:',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // White title for meal type
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70, // Light grey for details
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DietDialog extends StatefulWidget {
  final String uid;
  final DietPlan? diet;
  final Function(DietPlan) onSave;
  final String selectedDay;

  const _DietDialog({
    Key? key,
    required this.uid,
    this.diet,
    required this.onSave,
    required this.selectedDay,
  }) : super(key: key);

  @override
  State<_DietDialog> createState() => _DietDialogState();
}

class _DietDialogState extends State<_DietDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _breakfastController;
  late TextEditingController _lunchController;
  late TextEditingController _dinnerController;
  late TextEditingController _snackDetailsController;
  late bool _hasSnack;
  late bool _isCheatDay;

  @override
  void initState() {
    super.initState();
    _breakfastController = TextEditingController(text: widget.diet?.breakfast ?? '');
    _lunchController = TextEditingController(text: widget.diet?.lunch ?? '');
    _dinnerController = TextEditingController(text: widget.diet?.dinner ?? '');
    _snackDetailsController = TextEditingController(text: widget.diet?.snackDetails ?? '');
    _hasSnack = widget.diet?.hasSnack ?? false;
    _isCheatDay = widget.diet?.isCheatDay ?? false;

    if (_isCheatDay) {
      _breakfastController.text = '';
      _lunchController.text = '';
      _dinnerController.text = '';
      _snackDetailsController.text = '';
      _hasSnack = false;
    }
  }

  @override
  void dispose() {
    _breakfastController.dispose();
    _lunchController.dispose();
    _dinnerController.dispose();
    _snackDetailsController.dispose(); // Corrected: Dispose snackDetailsController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black87, // Dark background for dialog
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text(
        widget.diet == null ? 'Add Diet Plan for ${widget.selectedDay}' : 'Edit Diet Plan for ${widget.selectedDay}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), // White title
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('Cheat Day', style: TextStyle(color: Colors.white70)), // White text
                value: _isCheatDay,
                onChanged: (bool? newValue) {
                  setState(() {
                    _isCheatDay = newValue!;
                    if (_isCheatDay) {
                      _breakfastController.text = '';
                      _lunchController.text = '';
                      _dinnerController.text = '';
                      _snackDetailsController.text = '';
                      _hasSnack = false;
                    }
                  });
                },
                activeColor: Colors.deepOrangeAccent, // Orange checkbox
                checkColor: Colors.white,
              ),
              if (!_isCheatDay) ...[
                _buildTextFormField(
                  controller: _breakfastController,
                  labelText: 'Breakfast',
                  validatorText: 'Please enter breakfast plan',
                  context: context,
                ),
                _buildTextFormField(
                  controller: _lunchController,
                  labelText: 'Lunch',
                  validatorText: 'Please enter lunch plan',
                  context: context,
                ),
                _buildTextFormField(
                  controller: _dinnerController,
                  labelText: 'Dinner',
                  validatorText: 'Please enter dinner plan',
                  context: context,
                ),
                CheckboxListTile(
                  title: const Text('Include Snack?', style: TextStyle(color: Colors.white70)),
                  value: _hasSnack,
                  onChanged: (bool? newValue) {
                    setState(() {
                      _hasSnack = newValue!;
                      if (!_hasSnack) {
                        _snackDetailsController.text = '';
                      }
                    });
                  },
                  activeColor: Colors.deepOrangeAccent,
                  checkColor: Colors.white,
                ),
                if (_hasSnack)
                  _buildTextFormField(
                    controller: _snackDetailsController,
                    labelText: 'Snack Details',
                    validatorText: 'Please enter snack details',
                    context: context,
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)), // Light text
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final DietPlan diet = DietPlan(
                uid: widget.uid,
                dayOfWeek: widget.selectedDay,
                breakfast: _isCheatDay ? '' : _breakfastController.text,
                lunch: _isCheatDay ? '' : _lunchController.text,
                dinner: _isCheatDay ? '' : _dinnerController.text,
                hasSnack: _isCheatDay ? false : _hasSnack,
                snackDetails: _isCheatDay ? null : (_hasSnack ? _snackDetailsController.text : null),
                isCheatDay: _isCheatDay,
              );
              widget.onSave(diet);
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrangeAccent, // Orange save button
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required String validatorText,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: const TextStyle(color: Colors.white70), // Light label
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white38), // Subtle border
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.deepOrangeAccent, width: 2), // Orange focus border
            borderRadius: BorderRadius.circular(8),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.redAccent),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white10, // Very subtle fill
        ),
        style: const TextStyle(color: Colors.white), // White input text
        maxLines: null,
        keyboardType: TextInputType.multiline,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return validatorText;
          }
          return null;
        },
      ),
    );
  }
}