import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

// Date formatting helper (avoiding intl dependency)
String _formatTime(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
}

String _formatDate(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeService();
  runApp(const ChildTrackerApp());
}

class ChildTrackerApp extends StatelessWidget {
  const ChildTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Children Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
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
          return const RoleSelectorScreen();
        }

        // User is not logged in
        return const LoginScreen();
      },
    );
  }
}

class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final headline = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey.shade900,
        );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Soft gradient background with atmosphere
          Container(
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
          ),
          // Decorative circles for depth
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade100.withValues(alpha: 255 * 0.4),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.teal.shade100.withValues(alpha: 255 * 0.35),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Child Tracker', style: headline),
                                const SizedBox(height: 6),
                                Text(
                                  'Stay close. Stay safe.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 255 * 0.05),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.logout, color: Colors.red.shade400, size: 24),
                                    onPressed: () => _showLogoutDialog(context),
                                    tooltip: 'Sign out',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 255 * 0.05),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.my_location, color: Colors.blue, size: 28),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Hero card
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade600, Colors.teal.shade400],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade200.withValues(alpha: 255 * 0.5),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 255 * 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.satellite_alt, color: Colors.white, size: 28),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Real-time GPS safety',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Pick your role to start sharing or monitoring live location with instant alerts.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 255 * 0.9),
                                    ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Role cards
                        _RoleCard(
                          label: 'Child / Broadcaster',
                          description: 'Share your location securely in the background.',
                          icon: Icons.child_care,
                          color: Colors.blue.shade600,
                          accentColor: Colors.blue.shade100,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ChildModeScreen()),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _RoleCard(
                          label: 'Parent / Monitor',
                          description: 'View live location, distance, and safety radius.',
                          icon: Icons.shield_moon,
                          color: Colors.teal.shade600,
                          accentColor: Colors.teal.shade100,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ParentModeScreen()),
                          ),
                        ),

                        const SizedBox(height: 20),
                        Card(
                          color: Colors.amber.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.security, color: Colors.amber.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Grant location & notification permissions for best real-time accuracy.',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red.shade400),
            const SizedBox(width: 12),
            const Text('Sign Out'),
          ],
        ),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              AuthService().signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        shadowColor: color.withValues(alpha: 255 * 0.35),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
            border: Border.all(color: accentColor.withValues(alpha: 255 * 0.7)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 255 * 0.15),
                blurRadius: 14,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.grey.shade500),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Get started',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChildModeScreen extends StatefulWidget {
  const ChildModeScreen({super.key});

  @override
  State<ChildModeScreen> createState() => _ChildModeScreenState();
}

class _ChildModeScreenState extends State<ChildModeScreen> {
  final String _pairCode = _generatePairCode();
  bool _isStreaming = false;
  StreamSubscription<Position>? _positionSub;
  String _status = 'Idle';
  int _updateCount = 0;
  DateTime? _lastUpdate;

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  static String _generatePairCode() {
    final rng = Random();
    return (rng.nextInt(900000) + 100000).toString();
  }

  Future<void> _startStreaming() async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      setState(() => _status = 'Location permission denied');
      return;
    }
    
    final hasNotification = await _ensureNotificationPermission();
    if (!hasNotification) {
      setState(() => _status = 'Notification permission denied');
      return;
    }

    await ensureServiceStarted();

    // Inform background service which pairing code to use and start tracking there too.
    service.invoke('setPairCode', {'pairCode': _pairCode});
    service.invoke('startTracking');

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) async {
      await _uploadPosition(pos);
      setState(() {
        _status = 'Sharing location - last update: ${DateTime.now().toLocal().toString().split('.')[0]}';
        _updateCount++;
        _lastUpdate = DateTime.now();
      });
    });

    setState(() => _isStreaming = true);
  }

  Future<void> _stopStreaming() async {
    await _positionSub?.cancel();
    service.invoke('stopTracking');
    setState(() {
      _isStreaming = false;
      _status = 'Stopped sharing';
    });
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    return serviceEnabled;
  }

  Future<bool> _ensureNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> _uploadPosition(Position pos) async {
    final now = FieldValue.serverTimestamp();
    
    // Update main location document
    final doc = FirebaseFirestore.instance.collection('locations').doc(_pairCode);
    await doc.set({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'timestamp': now,
      'accuracy': pos.accuracy,
      'altitude': pos.altitude,
    });

    // Store in history
    await doc.collection('history').add({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'timestamp': now,
      'accuracy': pos.accuracy,
    });
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    final bannerColors = [Colors.blue.shade600, Colors.teal.shade500];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Mode - Location Sharing'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: bannerColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade200.withValues(alpha: 255 * 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 255 * 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.radar, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Broadcasting to parent', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Keep this screen open to stay in sync.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 255 * 0.9))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 255 * 0.2), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(_isStreaming ? Icons.circle : Icons.circle_outlined, color: Colors.white, size: 12),
                          const SizedBox(width: 6),
                          Text(_isStreaming ? 'Live' : 'Idle', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _GlassCard(
                child: Column(
                  children: [
                    Text('Share this code with parent', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                    const SizedBox(height: 12),
                    SelectableText(
                      _pairCode,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            letterSpacing: 4,
                            fontWeight: FontWeight.w900,
                            color: Colors.blue.shade800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Code'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _GlassCard(
                color: _isStreaming ? Colors.green.shade50 : Colors.grey.shade100,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isStreaming ? Icons.location_on : Icons.location_off,
                          color: _isStreaming ? Colors.green : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_isStreaming ? 'Sharing Location' : 'Not Sharing', style: titleStyle?.copyWith(color: _isStreaming ? Colors.green : Colors.grey)),
                              const SizedBox(height: 4),
                              Text(_status, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_isStreaming) ...[
                      const SizedBox(height: 12),
                      Divider(color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatChip(label: 'Updates sent', value: _updateCount.toString()),
                          _StatChip(label: 'Last update', value: _lastUpdate != null ? _formatTime(_lastUpdate!) : '--'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isStreaming ? null : _startStreaming,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Sharing'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green.shade600,
                        disabledBackgroundColor: Colors.grey[400],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isStreaming ? _stopStreaming : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Sharing'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _GlassCard(
                color: Colors.orange.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text('Tips for best accuracy', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Keep the app awake while pairing\n'
                      '• Allow "All the time" location on Android\n'
                      '• Ensure internet is on for uploads\n'
                      '• Share the code above with your parent',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ParentModeScreen extends StatefulWidget {
  const ParentModeScreen({super.key});

  @override
  State<ParentModeScreen> createState() => _ParentModeScreenState();
}

class _ParentModeScreenState extends State<ParentModeScreen> {
  final TextEditingController _codeController = TextEditingController();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _childSub;
  StreamSubscription<Position>? _parentPositionSub;
  double _radiusMeters = 100;
  double? _latestDistance;
  double? _lastSpeed;
  LatLng? _childLatLng;
  LatLng? _lastChildLatLng;
  Position? _parentPosition;
  DateTime? _lastChildUpdate;
  String _status = 'Not listening';
  bool _isListening = false;
  String? _linkedCode;

  @override
  void dispose() {
    _childSub?.cancel();
    _parentPositionSub?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showSnackBar('Please enter a pairing code');
      return;
    }

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      _showSnackBar('Location permission denied');
      return;
    }

    await _childSub?.cancel();
    await _parentPositionSub?.cancel();
    
    setState(() {
      _status = 'Connecting...';
      _isListening = true;
      _linkedCode = code;
      _latestDistance = null;
    });

    // Start monitoring parent's location in real-time
    _parentPositionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((parentPos) {
      if (_childLatLng != null) {
        _updateDistance(parentPos);
      } else {
        setState(() => _parentPosition = parentPos);
      }
    });

    // Listen to child's location updates
    _childSub = FirebaseFirestore.instance
        .collection('locations')
        .doc(code)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        setState(() => _status = 'Waiting for child to start sharing...');
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      final childLat = (data['latitude'] as num?)?.toDouble();
      final childLng = (data['longitude'] as num?)?.toDouble();
      if (childLat == null || childLng == null) return;

      final newChildLatLng = LatLng(childLat, childLng);
      
      // Calculate speed if we have a previous location
      if (_lastChildLatLng != null && _lastChildUpdate != null) {
        final distance = Geolocator.distanceBetween(
          _lastChildLatLng!.latitude,
          _lastChildLatLng!.longitude,
          childLat,
          childLng,
        );
        final now = DateTime.now();
        final timeDiff = now.difference(_lastChildUpdate!).inSeconds;
        if (timeDiff > 0) {
          _lastSpeed = (distance / timeDiff) * 3.6; // Convert m/s to km/h
        }
      }

      setState(() {
        _childLatLng = newChildLatLng;
        _lastChildLatLng = LatLng(childLat, childLng);
        _lastChildUpdate = DateTime.now();
        _status = 'Connected - tracking child';
      });

      // Update distance with current parent position
      if (_parentPosition != null) {
        _updateDistance(_parentPosition!);
      }
    });
  }

  void _updateDistance(Position parentPos) {
    if (_childLatLng == null) return;
    
    final distance = Geolocator.distanceBetween(
      parentPos.latitude,
      parentPos.longitude,
      _childLatLng!.latitude,
      _childLatLng!.longitude,
    );

    setState(() {
      _latestDistance = distance;
      _parentPosition = parentPos;
      _status = distance > _radiusMeters ? 'Out of range ⚠️' : 'Within range ✓';
    });
  }

  Future<void> _stopListening() async {
    await _childSub?.cancel();
    await _parentPositionSub?.cancel();
    setState(() {
      _isListening = false;
      _status = 'Stopped';
      _linkedCode = null;
      _latestDistance = null;
      _childLatLng = null;
      _lastSpeed = null;
    });
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    return serviceEnabled;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAlerting = (_latestDistance ?? 0) > _radiusMeters;
    final speedText = _lastSpeed != null ? _lastSpeed!.toStringAsFixed(1) : '--';
    final bannerColors = [Colors.teal.shade600, Colors.blue.shade500];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Mode'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: bannerColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade200.withValues(alpha: 255 * 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 255 * 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.map_outlined, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monitor your child live', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Connect with the code to begin tracking.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 255 * 0.9))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 255 * 0.2), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(_isListening ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: Colors.white, size: 12),
                          const SizedBox(width: 6),
                          Text(_isListening ? 'Listening' : 'Disconnected', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (!_isListening)
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Connect to Child', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _codeController,
                        enabled: !_isListening,
                        decoration: InputDecoration(
                          labelText: 'Enter child pairing code',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startListening,
                          icon: const Icon(Icons.link),
                          label: const Text('Connect & Monitor'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.blue.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isListening) ...[
                _GlassCard(
                  color: isAlerting ? Colors.red.shade50 : Colors.green.shade50,
                  child: Row(
                    children: [
                      Icon(isAlerting ? Icons.warning_amber : Icons.shield, color: isAlerting ? Colors.red : Colors.green, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_status, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: isAlerting ? Colors.red : Colors.green)),
                            const SizedBox(height: 4),
                            Text('Code: $_linkedCode', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                if (_latestDistance != null)
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Distance',
                          value: _latestDistance!.toStringAsFixed(0),
                          unit: 'm',
                          icon: Icons.straighten,
                          color: isAlerting ? Colors.red : Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Speed',
                          value: speedText,
                          unit: 'km/h',
                          icon: Icons.speed,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 14),

                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Safe Radius', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          Text('${_radiusMeters.toStringAsFixed(0)} m', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        min: 25,
                        max: 500,
                        divisions: 19,
                        value: _radiusMeters,
                        onChanged: (value) => setState(() => _radiusMeters = value),
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                if (_childLatLng != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MapViewScreen(
                              childPosition: _childLatLng!,
                              parentPosition: _parentPosition == null
                                  ? null
                                  : LatLng(_parentPosition!.latitude, _parentPosition!.longitude),
                              radiusMeters: _radiusMeters,
                              pairCode: _linkedCode ?? '',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('View on Map'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.purple,
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                if (_linkedCode != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LocationHistoryScreen(pairCode: _linkedCode!),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('View Location History'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.teal,
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _stopListening,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Monitoring'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Text(unit, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class MapViewScreen extends StatefulWidget {
  const MapViewScreen({
    super.key,
    required this.childPosition,
    required this.radiusMeters,
    required this.pairCode,
    this.parentPosition,
  });

  final LatLng childPosition;
  final LatLng? parentPosition;
  final double radiusMeters;
  final String pairCode;

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  GoogleMapController? _mapController;
  LatLng? _childPosition;
  LatLng? _parentPosition;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _childSub;
  StreamSubscription<Position>? _parentPosSub;
  bool _cameraFollowingChild = true;

  @override
  void initState() {
    super.initState();
    _childPosition = widget.childPosition;
    _parentPosition = widget.parentPosition;
    _listenToChildLocation();
    _listenToParentLocation();
  }

  @override
  void dispose() {
    _childSub?.cancel();
    _parentPosSub?.cancel();
    super.dispose();
  }

  Future<void> _listenToChildLocation() async {
    if (widget.pairCode.isEmpty) return;

    _childSub = FirebaseFirestore.instance
        .collection('locations')
        .doc(widget.pairCode)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;

      final childLat = (data['latitude'] as num?)?.toDouble();
      final childLng = (data['longitude'] as num?)?.toDouble();
      if (childLat == null || childLng == null) return;

      final newPos = LatLng(childLat, childLng);
      setState(() => _childPosition = newPos);

      // Keep the camera centered on the child unless the user moves it.
      if (_cameraFollowingChild && _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(newPos));
      }
    });
  }

  Future<void> _listenToParentLocation() async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;

    _parentPosSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      setState(() {
        _parentPosition = LatLng(pos.latitude, pos.longitude);
      });
    });
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    return serviceEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final childPosition = _childPosition ?? widget.childPosition;
    final parentPosition = _parentPosition;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('child'),
        position: childPosition,
        infoWindow: const InfoWindow(title: 'Child Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
      if (parentPosition != null)
        Marker(
          markerId: const MarkerId('parent'),
          position: parentPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
    };

    final circles = <Circle>{
      Circle(
        circleId: const CircleId('radius'),
        center: childPosition,
        radius: widget.radiusMeters,
        strokeWidth: 2,
        strokeColor: Colors.green.withValues(alpha: 255 * 0.8),
        fillColor: Colors.green.withValues(alpha: 255 * 0.2),
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Location Map'),
        backgroundColor: Colors.purple,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: childPosition, zoom: 17),
        markers: markers,
        circles: circles,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (controller) => _mapController = controller,
        onCameraMoveStarted: () => _cameraFollowingChild = false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _childPosition == null || _mapController == null
            ? null
            : () {
                _cameraFollowingChild = true;
                _mapController!.animateCamera(CameraUpdate.newLatLng(_childPosition!));
              },
        label: const Text('Center on Child'),
        icon: const Icon(Icons.my_location),
      ),
    );
  }
}

class LocationHistoryScreen extends StatefulWidget {
  const LocationHistoryScreen({super.key, required this.pairCode});

  final String pairCode;

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  late CollectionReference _historyRef;

  @override
  void initState() {
    super.initState();
    _historyRef = FirebaseFirestore.instance
        .collection('locations')
        .doc(widget.pairCode)
        .collection('history');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location History'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _historyRef.orderBy('timestamp', descending: true).limit(100).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No location history yet'),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final lat = (data['latitude'] as num?)?.toDouble() ?? 0;
              final lng = (data['longitude'] as num?)?.toDouble() ?? 0;
              final timestamp = data['timestamp'] as Timestamp?;
              
              final dateTime = timestamp?.toDate() ?? DateTime.now();
              final timeStr = _formatTime(dateTime);
              final dateStr = _formatDate(dateTime);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.red),
                    title: Text('$lat, $lng'),
                    subtitle: Text('$dateStr at $timeStr'),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MapViewScreen(
                              childPosition: LatLng(lat, lng),
                              radiusMeters: 100,
                              pairCode: widget.pairCode,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  StreamSubscription<Position>? bgStream;
  String? pairCode;

  Future<void> startTracking() async {
    await bgStream?.cancel();
    bgStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) async {
      final code = pairCode;
      if (code == null) return;
      await FirebaseFirestore.instance.collection('locations').doc(code).set({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  service.on('setPairCode').listen((event) {
    pairCode = event?['pairCode'] as String?;
  });

  service.on('startTracking').listen((event) {
    startTracking();
  });

  service.on('stopTracking').listen((event) async {
    await bgStream?.cancel();
  });

  service.on('stopService').listen((event) async {
    await bgStream?.cancel();
    service.stopSelf();
  });

  if (service is AndroidServiceInstance) {
    final androidService = service as AndroidServiceInstance;
    await androidService.setForegroundNotificationInfo(
      title: 'Child Tracker',
      content: 'Sharing location in background',
    );
    await androidService.setAsForegroundService();
  }
}

final service = FlutterBackgroundService();

Future<void> initializeService() async {
  // Configure the service (Android Notification/iOS setup)
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: 'child_tracker_channel',
      foregroundServiceTypes: [AndroidForegroundType.location],
      initialNotificationTitle: 'Child Tracker',
      initialNotificationContent: 'Sharing location in background',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: (ServiceInstance service) {
        onStart(service);
        return true;
      },
    ),
  );
}

Future<void> ensureServiceStarted() async {
  final running = await service.isRunning();
  if (!running) {
    await service.startService();
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: color ?? Colors.white.withValues(alpha: 255 * 0.9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}