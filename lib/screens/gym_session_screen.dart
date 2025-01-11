import 'package:flutter/material.dart';

class GymSessionScreen extends StatelessWidget {
  const GymSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gym Session')),
      body: const Center(child: Text('Gym Session Screen')),
    );
  }
}