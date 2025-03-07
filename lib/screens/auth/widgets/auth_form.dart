import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      widget.setLoading(true);
      try {
        UserCredential? userCredential;
        if (_isLogin) {
          userCredential = await AuthService().signInWithEmailAndPassword(
              _emailController.text.trim(), _passwordController.text.trim());
        } else {
          userCredential = await AuthService().signUpWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text.trim(),
            _nameController.text.trim(), // Pass name
            int.tryParse(_ageController.text.trim()) ?? 0, // Pass age (parse to int)
            double.tryParse(_weightController.text.trim()) ?? 0.0, // Pass weight (parse to double)
            double.tryParse(_heightController.text.trim()) ?? 0.0, // Pass height (parse to double)
          );
          if (userCredential != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User created successfully!')),
            );
          }
        }
        if (userCredential != null) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        String errorMessage = 'An error occurred.';
        if (e is String) {
          errorMessage = e;
        } else if (e is FirebaseException) {
          errorMessage = e.message ?? errorMessage;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } finally {
        widget.setLoading(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (!_isLogin) // Only show these on signup
            TextFormField(
              key: const ValueKey('name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name.';
                }
                return null;
              },
            ),
          TextFormField(
            key: const ValueKey('email'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (value) {
              if (value == null || value.isEmpty || !value.contains('@')) {
                return 'Please enter a valid email address.';
              }
              return null;
            },
          ),
          TextFormField(
            key: const ValueKey('password'),
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (value) {
              if (value == null || value.isEmpty || value.length < 6) {
                return 'Password must be at least 6 characters long.';
              }
              return null;
            },
          ),
          if (!_isLogin) // Only show these on signup
            TextFormField(
              key: const ValueKey('age'),
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
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
          if (!_isLogin) // Only show these on signup
            TextFormField(
              key: const ValueKey('weight'),
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
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
          if (!_isLogin) // Only show these on signup
            TextFormField(
              key: const ValueKey('height'),
              controller: _heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Height (cm)'),
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
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _submitForm,
            child: Text(_isLogin ? 'Login' : 'Sign Up'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _isLogin = !_isLogin;
              });
            },
            child: Text(_isLogin
                ? 'Create an account'
                : 'Already have an account?'),
          ),
        ],
      ),
    );
  }
}