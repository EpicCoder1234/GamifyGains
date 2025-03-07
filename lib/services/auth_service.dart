// auth_service.dart
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gamify_gains/models/user.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  Future<firebase_auth.UserCredential?> signUpWithEmailAndPassword(
    String email,
    String password,
    String name,
    int age,
    double weight,
    double height,
  ) async {
    try {
      firebase_auth.UserCredential userCredential = // Use the prefix here
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User newUser = User(
        uid: userCredential.user!.uid,
        name: name,
        age: age,
        weight: weight,
        height: height,
      );

      await _firestore
          .collection('users')
          .doc(newUser.uid)
          .set(newUser.toFirestore());

      return userCredential;
    } on firebase_auth.FirebaseAuthException catch (e) { // Prefix here as well!
      // ... (error handling)
    } catch (e) {
      rethrow;
    }
  }
Future<firebase_auth.UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      firebase_auth.UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        throw 'Wrong password provided for that user.';
      } else {
        throw e.message ?? 'Login failed'; // Re-throw other Firebase Auth errors
      }
    } catch (e) {
      throw 'Login failed: $e'; // Catch other exceptions
    }
  }

  firebase_auth.User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}