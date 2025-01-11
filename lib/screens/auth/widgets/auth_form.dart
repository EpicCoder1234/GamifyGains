import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';

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
  bool _isLogin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save(); // Save the form values
      widget.setLoading(true);
      try {
        if (_isLogin) {
          await AuthService().signInWithEmailAndPassword(
              _emailController.text.trim(), _passwordController.text.trim());
        } else {
          await AuthService().signUpWithEmailAndPassword(
              _emailController.text.trim(), _passwordController.text.trim());
        }
      } catch (e) {
        String errorMessage = 'An error occurred.';
        if (e is FirebaseException) {
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