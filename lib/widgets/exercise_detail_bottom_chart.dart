import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // For opening video links
import '../models/exercise.dart'; // Ensure this path is correct

class ExerciseDetailBottomSheet extends StatelessWidget {
  final Exercise exercise;
  // This callback will be provided by the ExerciseSelectionScreen
  final Function(Exercise) onConfirmExercise;

  const ExerciseDetailBottomSheet({
    Key? key,
    required this.exercise,
    required this.onConfirmExercise,
  }) : super(key: key);

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication); // Opens in browser
    } else {
      // Handle the error, e.g., show a Snackbar. You might want to pass context here
      // or use a global messenger key for more robust error reporting.
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Apply consistent styling for the bottom sheet
      decoration: BoxDecoration(
        color: Colors.blueGrey[900], // Dark background for the sheet
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Keep content tight
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise Name at the top (centered)
            Align(
              alignment: Alignment.center,
              child: Text(
                exercise.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            if (exercise.description != null && exercise.description!.isNotEmpty) ...[
              const Text(
                'Description:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                exercise.description!,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 12),
            ],

            // Category
            const Text(
              'Category:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              exercise.category,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 12),

            // Target Muscles
            if (exercise.targetMuscles.isNotEmpty) ...[
              const Text(
                'Target Muscles:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                exercise.targetMuscles.join(', '), // Join list into a string
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 12),
            ],

            // Equipment
            if (exercise.equipment != null && exercise.equipment!.isNotEmpty) ...[
              const Text(
                'Equipment:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                exercise.equipment!.join(', '),
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 12),
            ],

            // Difficulty
            if (exercise.difficulty != null && exercise.difficulty!.isNotEmpty) ...[
              const Text(
                'Difficulty:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                exercise.difficulty!,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 12),
            ],

            // Video Link (if available)
            if (exercise.videoLink != null && exercise.videoLink!.isNotEmpty) ...[
              GestureDetector(
                onTap: () {
                  _launchUrl(exercise.videoLink!);
                  // Optionally show a loading indicator or message here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening video link...')),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Keep row tight to content
                  children: [
                    const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 28),
                    const SizedBox(width: 8),
                    Flexible( // To prevent overflow if link is long
                      child: Text(
                        'Watch Video',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.redAccent,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 20),

            // Confirm Exercise Button
            SizedBox(
              width: double.infinity, // Make button full width
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close this bottom sheet
                  onConfirmExercise(exercise); // Call the callback to open WorkoutDialog
                },
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
                label: const Text(
                  'Confirm Exercise',
                  style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700, // Vibrant green
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 8,
                  shadowColor: Colors.green.shade900,
                ),
              ),
            ),
            // Add padding for the soft keyboard
            Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}