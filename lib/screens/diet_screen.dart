import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/diet_plan.dart';
import '../services/database_helper.dart';
import '/widgets/llm_integration.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({Key? key}) : super(key: key);

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  final dbHelper = DatabaseHelper();
  List<DietPlan> dietPlans = [];
  String _selectedDay = DateFormat('EEEE').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _checkDatabaseVersion();
  }

  Future<void> _checkDatabaseVersion() async {
    final currentVersion = await dbHelper.getCurrentDatabaseVersion();
    print('Current database version: $currentVersion');

    if (currentVersion < DatabaseHelper.databaseVersion) {
      print('Database needs upgrade!');
      await dbHelper.database;
      print("Database opened to trigger upgrade");
    } else {
      print('Database is up to date.');
    }
    await _loadDietPlans(_selectedDay);
  }


  Future<void> _loadDietPlans(String day) async {
    print("Loading diet plans for day: $day");
    dietPlans = await dbHelper.getDietPlans(day);
    print("Loaded diet plans: $dietPlans");
    setState(() {});
  }

  Future<void> _navigateToLLM() async {
    print("Navigating to LLM screen");
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => LLMIntegrationScreen(selectedDay: _selectedDay),
      ),
    );

    print("Back from LLM screen");

    if (result != null) {
      print("Received result: $result");
      print('_selectedDay in navigateToLLM: $_selectedDay');
      if (dietPlans.isNotEmpty) {
        print("Updating existing plan");
        DietPlan updatedPlan = DietPlan(
            id: dietPlans.first.id, day: _selectedDay, plan: result);
        await dbHelper.updateDietPlan(updatedPlan);
      } else {
        print("Creating new plan");
        final newDietPlan = DietPlan(id: const Uuid().v4(), day: _selectedDay, plan: result);
        await dbHelper.insertDietPlan(newDietPlan);
      }
      await _loadDietPlans(_selectedDay);
      print("Diet Plans after load: $dietPlans");
    } else {
      print("Result is null (user cancelled)");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diet Plans')),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToLLM,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dietPlans.isNotEmpty)
                ...dietPlans.map((plan) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Diet Plan for ${_selectedDay}"),
                            TextFormField(
                              initialValue: plan.plan,
                              maxLines: null,
                              onChanged: (value) async {
                                DietPlan updatedPlan = DietPlan(
                                  id: plan.id,
                                  day: plan.day,
                                  plan: value,
                                );
                                print("Updating existing plan");
                                await dbHelper.updateDietPlan(updatedPlan);
                                await _loadDietPlans(_selectedDay);
                              },
                            ),
                          ],
                        ),
                      ),
                    )),
              if (dietPlans.isEmpty) const Text("No diet plans yet."),
            ],
          ),
        ),
      ),
    );
  }
}