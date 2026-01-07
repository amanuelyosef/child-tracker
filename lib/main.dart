import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'config/app_theme.dart';
import 'firebase_options.dart';
import 'screens/child_mode_screen.dart';
import 'screens/login_screen.dart';
import 'screens/parent_mode_screen.dart';
import 'screens/role_selector_screen.dart';
import 'services/auth_service.dart';
import 'services/background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureFirebaseInitialized();
  await initializeBackgroundService();
  runApp(const ChildTrackerApp());
}

/// Ensure Firebase is initialized (safe for multiple calls)
Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } on FirebaseException catch (e) {
    // Ignore duplicate init caused by hot reload or background isolate
    if (e.code != 'duplicate-app' && e.code != 'app/duplicate-app') rethrow;
  } catch (_) {
    // Swallow unexpected duplicates to avoid app crash
  }
}

/// Main application widget
class ChildTrackerApp extends StatelessWidget {
  const ChildTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Children Tracker',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

/// Wrapper that listens to auth state and shows appropriate screen
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          return RoleBasedNavigator(user: snapshot.data!);
        }

        // User is not logged in
        return const LoginScreen();
      },
    );
  }
}

/// Navigates to the appropriate screen based on user role
class RoleBasedNavigator extends StatefulWidget {
  final User user;
  
  const RoleBasedNavigator({super.key, required this.user});

  @override
  State<RoleBasedNavigator> createState() => _RoleBasedNavigatorState();
}

class _RoleBasedNavigatorState extends State<RoleBasedNavigator> {
  final AuthService _authService = AuthService();
  UserRole? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    debugPrint('RoleBasedNavigator: Loading user role for UID: ${widget.user.uid}');
    final role = await _authService.getUserRole(widget.user.uid);
    debugPrint('RoleBasedNavigator: Got role: $role');
    if (mounted) {
      setState(() {
        _userRole = role;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade50,
                Colors.white,
                Colors.teal.shade50,
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading your profile...'),
              ],
            ),
          ),
        ),
      );
    }

    // If no role found (old user or error), show role selector
    if (_userRole == null) {
      return const RoleSelectorScreen();
    }

    // Navigate based on role
    if (_userRole == UserRole.child) {
      return const ChildModeScreen();
    } else {
      return const ParentModeScreen();
    }
  }
}
