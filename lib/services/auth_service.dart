import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'user_service.dart';

// Re-export UserRole for convenience
export '../models/user_model.dart' show UserRole;

/// Authentication service for handling user sign-in, registration, and auth state
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  /// Get current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred. Please try again.');
    }
  }

  /// Register with email and password
  /// Returns AuthResult with pairCode for child users
  Future<AuthResult> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    debugPrint('=== REGISTRATION START ===');
    debugPrint('Email: $email, Role: $role, Name: $displayName');
    
    User? user;
    try {
      debugPrint('Step 1: Creating Firebase Auth user...');
      
      // Wrap in try-catch because of known Flutter/Firebase plugin bug
      // that throws "type 'List<Object?>' is not a subtype of type 'PigeonUserDetails?'"
      // The user IS created, but the response parsing fails
      try {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        user = credential.user;
        debugPrint('Step 1 DONE: Firebase Auth user created via credential');
      } catch (createError) {
        if (createError.toString().contains('PigeonUserDetails') ||
            createError.toString().contains('List<Object?>')) {
          // Known bug - user was likely created, get current user
          debugPrint('Step 1 WARNING: Known plugin bug, checking currentUser...');
          await Future.delayed(const Duration(milliseconds: 500)); // Brief delay
          user = _auth.currentUser;
          if (user != null) {
            debugPrint('Step 1 RECOVERED: Got user from currentUser');
          }
        } else {
          rethrow; // Other errors should be handled normally
        }
      }

      if (user == null) {
        debugPrint('ERROR: user is null');
        return AuthResult.failure('Failed to create account.');
      }

      final uid = user.uid;
      debugPrint('User UID: $uid');

      // Update display name in Firebase Auth (ignore errors - known Flutter bug)
      debugPrint('Step 2: Updating display name...');
      try {
        await user.updateDisplayName(displayName);
        debugPrint('Step 2 DONE: Display name updated');
      } catch (displayNameError) {
        debugPrint('Step 2 WARNING: updateDisplayName failed (known bug): $displayNameError');
        // Continue anyway - the display name will be stored in Firestore
      }

      String? pairCode;

      // Create user in Firestore based on role
      debugPrint('Step 3: Creating Firestore document...');
      try {
        if (role == UserRole.parent) {
          debugPrint('Creating PARENT user in Firestore...');
          await _userService.createParentUser(
            uid: uid,
            email: email.trim(),
            displayName: displayName,
          );
          debugPrint('PARENT user created successfully!');
        } else {
          debugPrint('Creating CHILD user in Firestore...');
          pairCode = await _userService.createChildUser(
            uid: uid,
            email: email.trim(),
            displayName: displayName,
          );
          debugPrint('CHILD user created successfully! PairCode: $pairCode');
        }
      } catch (firestoreError) {
        debugPrint('!!! FIRESTORE ERROR: $firestoreError');
        // If Firestore fails, delete the Firebase Auth user to keep things consistent
        debugPrint('Attempting to delete auth user...');
        try {
          await user.delete();
          debugPrint('Auth user deleted');
        } catch (deleteError) {
          debugPrint('Failed to delete auth user: $deleteError');
        }
        return AuthResult.failure('Failed to save user data: $firestoreError');
      }

      debugPrint('=== REGISTRATION SUCCESS ===');
      return AuthResult.success(pairCode: pairCode);
    } on FirebaseAuthException catch (e) {
      debugPrint('!!! FIREBASE AUTH ERROR: ${e.code} - ${e.message}');
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      debugPrint('!!! UNEXPECTED ERROR: $e');
      // If something failed after auth was created, try to clean up
      if (user != null) {
        try {
          await user.delete();
        } catch (_) {
          // Ignore cleanup errors
        }
      }
      return AuthResult.failure('An unexpected error occurred: $e');
    }
  }

  /// Get user role from Firestore
  Future<UserRole?> getUserRole(String uid) async {
    debugPrint('AuthService.getUserRole called for UID: $uid');
    final user = await _userService.getUser(uid);
    debugPrint('AuthService.getUserRole: user = $user, role = ${user?.role}');
    return user?.role;
  }

  /// Get current app user
  Future<AppUser?> getCurrentAppUser() async {
    final firebaseUser = currentUser;
    if (firebaseUser == null) return null;
    return _userService.getUser(firebaseUser.uid);
  }

  /// Get current user as ParentUser
  Future<ParentUser?> getCurrentParentUser() async {
    final firebaseUser = currentUser;
    if (firebaseUser == null) return null;
    return _userService.getParentUser(firebaseUser.uid);
  }

  /// Get current user as ChildUser
  Future<ChildUser?> getCurrentChildUser() async {
    final firebaseUser = currentUser;
    if (firebaseUser == null) return null;
    return _userService.getChildUser(firebaseUser.uid);
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred. Please try again.');
    }
  }

  /// Update password
  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      await currentUser?.updatePassword(newPassword);
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred. Please try again.');
    }
  }

  /// Get user-friendly error messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'requires-recent-login':
        return 'Please sign out and sign in again to perform this action.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}

/// Result of an authentication operation
class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final String? pairCode; // Only set for child registration

  AuthResult._({
    required this.isSuccess,
    this.errorMessage,
    this.pairCode,
  });

  factory AuthResult.success({String? pairCode}) =>
      AuthResult._(isSuccess: true, pairCode: pairCode);

  factory AuthResult.failure(String message) =>
      AuthResult._(isSuccess: false, errorMessage: message);
}
