import 'package:flutter/material.dart';
import '../../widgets/loading_indicator.dart'; // Make sure this path is correct
import 'widgets/auth_form.dart'; // Make sure this path is correct

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;

  void _setLoading(bool value) {
    if(mounted){
    setState(() {
      _isLoading = value;
    });
    }
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove AppBar as the design is full-screen with custom title
      // appBar: AppBar(title: const Text('Authentication')),
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/barbell_background.png'), // Use your background image
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Gradient Overlay for better readability

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // START OF MODIFICATION: Add your logo here
                  Image.asset(
                    'assets/gamify_gains_logo.png', // Replace 'app_logo.png' with your actual logo file name
                    height: 120, // Adjust the height as needed
                    width: 120,  // Adjust the width as needed, or remove for intrinsic ratio
                    // fit: BoxFit.contain, // Use BoxFit if you want to control how it scales
                  ),
                  const SizedBox(height: 20), // Spacing between logo and title
                  // END OF MODIFICATION

                  // Title with bold text and period
                  const Text(
                    'Gamify Gains.',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(2.0, 2.0),
                          blurRadius: 3.0,
                          color: Color.fromARGB(150, 0, 0, 0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Authentication Card wrapping AuthForm
                  // Note: _isLoading logic is being moved to AuthForm.
                  // The FadeTransition and Card styling are now here.
                  Card(
                    margin: const EdgeInsets.all(16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0), // Rounded card corners
                    ),
                    elevation: 10,
                    color: Colors.white.withOpacity(0.9), // Semi-transparent white card
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      // Your AuthForm will go here. The 'setLoading' prop will be removed from AuthForm later.
                      child: AuthForm(setLoading: _setLoading), // <--- No longer pass setLoading here
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Show loading indicator if _isLoading is true
          if (_isLoading)
            const LoadingIndicator(), // Ensure LoadingIndicator is a widget that overlays
        ],
      ),
    );
  }

}