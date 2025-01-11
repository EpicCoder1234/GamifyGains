import 'package:flutter/material.dart';
import '../../widgets/loading_indicator.dart';
import 'widgets/auth_form.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;

  void _setLoading(bool value) {
    setState(() {
      _isLoading = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentication')),
      body: _isLoading
          ? const LoadingIndicator() // Show loading indicator
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AuthForm(setLoading: _setLoading),
              ),
            ),
    );
  }
}