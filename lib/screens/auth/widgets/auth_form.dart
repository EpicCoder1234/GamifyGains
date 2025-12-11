import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseAuthException
// Removed DatabaseHelper and user_model import as they are not used in this file's logic
// Removed LoadingIndicator import as the parent handles it based on setLoading

class AuthForm extends StatefulWidget {
  final Function(bool) setLoading;

  const AuthForm({Key? key, required this.setLoading}) : super(key: key);

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); // Name controller
  final _ageController = TextEditingController(); // Age controller
  final _weightController = TextEditingController(); // Weight controller
  final _heightController = TextEditingController(); // Height controller
  bool _isLogin = true;
  String? _errorMessage; // To display authentication errors within the form

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      setState(() {
        _errorMessage = null; // Clear previous error messages
      });
      widget.setLoading(true); // Start loading spinner on parent

      try {
        // Corrected to use the existing internal _isLogin logic
        UserCredential? userCredential;
        if (_isLogin) {
          userCredential = await AuthService().signInWithEmailAndPassword(
              _emailController.text.trim(), _passwordController.text.trim());
        } else {
          // Ensure these fields are validated before calling signUpWithEmailAndPassword
          if (_nameController.text.trim().isEmpty ||
              _ageController.text.trim().isEmpty || int.tryParse(_ageController.text.trim()) == null ||
              _weightController.text.trim().isEmpty || double.tryParse(_weightController.text.trim()) == null ||
              _heightController.text.trim().isEmpty || double.tryParse(_heightController.text.trim()) == null) {
            setState(() {
              _errorMessage = 'Please fill all required fields for registration.';
            });
            widget.setLoading(false);
            return;
          }

          userCredential = await AuthService().signUpWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text.trim(),
            _nameController.text.trim(),
            int.parse(_ageController.text.trim()),
            double.parse(_weightController.text.trim()),
            double.parse(_heightController.text.trim()),
          );
          if (userCredential != null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User created successfully!')),
              );
            }
          }
        }
        if (userCredential != null) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      } on FirebaseAuthException catch (e) {
        String message = 'An authentication error occurred. Please check your credentials.';
        if (e.code == 'weak-password') {
          message = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          message = 'The account already exists for that email.';
        } else if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          message = 'Invalid email or password.';
        } else if (e.code == 'invalid-email') {
          message = 'The email address is not valid.';
        }
        if (mounted) {
          setState(() {
            _errorMessage = message;
          });
        }
      } catch (e) {
        String errorMessage = 'An unexpected error occurred.';
        if (e is String) {
          errorMessage = e;
        }
        if (mounted) {
          setState(() {
            _errorMessage = errorMessage;
          });
        }
      } finally {
        if (mounted) {
          widget.setLoading(false); // Stop loading spinner on parent
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min, // Ensure the column takes minimal space
        children: [
          // Error Message Display
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          if (!_isLogin) // Only show these on signup
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: TextFormField(
                key: const ValueKey('name'),
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: const Icon(Icons.person, color: Colors.deepOrangeAccent), // Added icon
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0), // Rounded input field
                    borderSide: BorderSide.none, // No border for a cleaner look
                  ),
                  filled: true,
                  fillColor: Colors.grey[200], // Background color
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name.';
                  }
                  return null;
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: TextFormField(
              key: const ValueKey('email'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email, color: Colors.deepOrangeAccent), // Added icon
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0), // Rounded input field
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              validator: (value) {
                if (value == null || value.isEmpty || !value.contains('@')) {
                  return 'Please enter a valid email address.';
                }
                return null;
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: TextFormField(
              key: const ValueKey('password'),
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock, color: Colors.deepOrangeAccent), // Added icon
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0), // Rounded input field
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              validator: (value) {
                if (value == null || value.isEmpty || value.length < 6) {
                  return 'Password must be at least 6 characters long.';
                }
                return null;
              },
            ),
          ),
          if (!_isLogin) // Only show these on signup
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: TextFormField(
                key: const ValueKey('age'),
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Age',
                  prefixIcon: const Icon(Icons.cake, color: Colors.deepOrangeAccent), // Added icon
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your age.';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number for age';
                  }
                  return null;
                },
              ),
            ),
          if (!_isLogin) // Only show these on signup
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: TextFormField(
                key: const ValueKey('weight'),
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Weight (lbs)',
                  prefixIcon: const Icon(Icons.fitness_center, color: Colors.deepOrangeAccent), // Added icon
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your weight.';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number for weight';
                  }
                  return null;
                },
              ),
            ),
          if (!_isLogin) // Only show these on signup
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: TextFormField(
                key: const ValueKey('height'),
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Height (inches)',
                  prefixIcon: const Icon(Icons.height, color: Colors.deepOrangeAccent), // Added icon
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your height.';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number for height';
                  }
                  return null;
                },
              ),
            ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrangeAccent, // Strong button color
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0), // More rounded button
              ),
              elevation: 5,
              shadowColor: Colors.deepOrangeAccent.withOpacity(0.5),
            ),
            child: Text(
              _isLogin ? 'LOGIN' : 'SIGN UP',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              setState(() {
                _isLogin = !_isLogin;
                _errorMessage = null; // Clear error message on toggle
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.deepOrangeAccent, // Text button color
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              side: const BorderSide(color: Colors.deepOrangeAccent, width: 1.5), // Subtle border
            ),
            child: Text(
              _isLogin
                  ? 'Create an account'
                  : 'Already have an account?',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
