// auth_service.dart
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gamify_gains/models/user.dart'; // Make sure this path is correct

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
      firebase_auth.UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        print("DEBUG: Firebase user is null after sign up. Throwing exception.");
        throw Exception("Firebase user is null after sign up.");
      }

      User newUser = User(
        uid: userCredential.user!.uid,
        name: name,
        age: age,
        weight: weight,
        height: height,
        weeklyGymTime: 0,
      );

      print("DEBUG: Attempting to save new user document to Firestore: ${newUser.uid}");
      await _firestore
          .collection('users')
          .doc(newUser.uid)
          .set(newUser.toFirestore());
      print("DEBUG: User document successfully saved for: ${newUser.uid}");

      return userCredential;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print("DEBUG: FirebaseAuthException during sign up: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      print("DEBUG: Unexpected error during sign up: $e");
      rethrow;
    }
  }

  Future<firebase_auth.UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      print("DEBUG: Attempting to sign in with email: $email");
      firebase_auth.UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("DEBUG: Firebase Auth sign-in successful.");

      firebase_auth.User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        print("DEBUG: Authenticated user UID: ${firebaseUser.uid}");
        print("DEBUG: Checking Firestore for user document.");
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();

        if (!userDoc.exists) {
          print('DEBUG: Firestore user document NOT FOUND for UID: ${firebaseUser.uid}.');
          // If the user document does NOT exist, create a new one.
          User defaultUser = User(
            uid: firebaseUser.uid,
            name: firebaseUser.displayName ?? 'New User',
            age: 0,
            weight: 0.0,
            height: 0.0,
            weeklyGymTime: 0,
          );
          print('DEBUG: Attempting to create new Firestore user document for UID: ${defaultUser.uid}');
          try {
            await _firestore.collection('users').doc(defaultUser.uid).set(defaultUser.toFirestore());
            print('DEBUG: Successfully created new Firestore user document for UID: ${defaultUser.uid} on login.');
          } catch (e) {
            print('ERROR: Failed to create Firestore user document for UID ${defaultUser.uid} during login: $e');
            // Optionally re-throw or show a persistent error to the user
          }
        } else {
          print('DEBUG: Firestore user document FOUND for UID: ${firebaseUser.uid}.');
        }
      } else {
        print("DEBUG: firebaseUser is null after sign-in. This is unexpected.");
      }

      return userCredential;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print("DEBUG: FirebaseAuthException during sign in: ${e.code} - ${e.message}");
      if (e.code == 'user-not-found') {
        throw 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        throw 'Wrong password provided for that user.';
      } else {
        throw e.message ?? 'Login failed due to an unknown Firebase Auth error.';
      }
    } catch (e) {
      print("DEBUG: Unexpected error during sign in: $e");
      throw 'Login failed: An unexpected error occurred.';
    }
  }

  firebase_auth.User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<void> signOut() async {
    print("DEBUG: Attempting to sign out.");
    await _auth.signOut();
    print("DEBUG: User signed out.");
  }
}
