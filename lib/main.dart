import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
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
      home: const RoleSelectorScreen(),
    );
  }
}

class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Mode')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RoleCard(
              label: 'Child (Broadcaster)',
              icon: Icons.satellite_alt,
              color: Colors.blue.shade600,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChildModeScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _RoleCard(
              label: 'Parent (Listener)',
              icon: Icons.hearing,
              color: Colors.green.shade700,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ParentModeScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 255 * 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 255 * 0.6)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
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
      setState(() => _status = 'Last push: ${DateTime.now().toLocal()}');
    });

    setState(() => _isStreaming = true);
  }

  Future<void> _stopStreaming() async {
    await _positionSub?.cancel();
    service.invoke('stopTracking');
    setState(() {
      _isStreaming = false;
      _status = 'Stopped';
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
    final doc = FirebaseFirestore.instance.collection('locations').doc(_pairCode);
    await doc.set({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Child Mode')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pairing code', style: Theme.of(context).textTheme.titleMedium),
            SelectableText(
              _pairCode,
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(letterSpacing: 2, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Status: $_status'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isStreaming ? null : _startStreaming,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start sharing'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isStreaming ? _stopStreaming : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Keep this screen running and grant "Allow all the time" location permission on Android.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
  double _radiusMeters = 100;
  double? _latestDistance;
  LatLng? _childLatLng;
  Position? _parentPosition;
  String _status = 'Not listening';

  @override
  void dispose() {
    _childSub?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _status = 'Enter a code');
      return;
    }

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      setState(() => _status = 'Location permission denied');
      return;
    }

    await _childSub?.cancel();
    setState(() {
      _status = 'Listening...';
      _latestDistance = null;
    });

    _childSub = FirebaseFirestore.instance
        .collection('locations')
        .doc(code)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        setState(() => _status = 'Waiting for child...');
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      final childLat = (data['latitude'] as num?)?.toDouble();
      final childLng = (data['longitude'] as num?)?.toDouble();
      if (childLat == null || childLng == null) return;

      final parentPos = await Geolocator.getCurrentPosition();
      final distance = Geolocator.distanceBetween(
        parentPos.latitude,
        parentPos.longitude,
        childLat,
        childLng,
      );

      setState(() {
        _latestDistance = distance;
        _parentPosition = parentPos;
        _childLatLng = LatLng(childLat, childLng);
        _status = distance > _radiusMeters ? 'Out of range' : 'Within range';
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

  Future<bool> _ensureNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    final isAlerting = (_latestDistance ?? 0) > _radiusMeters;

    return Scaffold(
      appBar: AppBar(title: const Text('Parent Mode')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Child pairing code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startListening,
                    icon: const Icon(Icons.link),
                    label: const Text('Link & listen'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Allowed radius: ${_radiusMeters.toStringAsFixed(0)} m'),
            Slider(
              min: 25,
              max: 500,
              divisions: 19,
              value: _radiusMeters,
              onChanged: (value) => setState(() => _radiusMeters = value),
            ),
            const SizedBox(height: 12),
            if (_latestDistance != null)
              Text(
                'Distance: ${_latestDistance!.toStringAsFixed(1)} m',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isAlerting ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            if (_childLatLng != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MapViewScreen(
                          childPosition: _childLatLng!,
                          parentPosition: _parentPosition == null
                              ? null
                              : LatLng(
                                  _parentPosition!.latitude,
                                  _parentPosition!.longitude,
                                ),
                          radiusMeters: _radiusMeters,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('View on map'),
                ),
              ),
            const SizedBox(height: 8),
            Text('Status: $_status'),
            if (isAlerting)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: const [
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(child: Text('Child is outside the safe radius!')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class MapViewScreen extends StatelessWidget {
  const MapViewScreen({
    super.key,
    required this.childPosition,
    required this.radiusMeters,
    this.parentPosition,
  });

  final LatLng childPosition;
  final LatLng? parentPosition;
  final double radiusMeters;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('child'),
        position: childPosition,
        infoWindow: const InfoWindow(title: 'Child'),
      ),
      if (parentPosition != null)
        Marker(
          markerId: const MarkerId('parent'),
          position: parentPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Parent'),
        ),
    };

    final circles = <Circle>{
      Circle(
        circleId: const CircleId('radius'),
        center: childPosition,
        radius: radiusMeters,
        strokeWidth: 2,
        strokeColor: Colors.green.withValues(alpha: 255 * 0.6),
        fillColor: Colors.green.withValues(alpha: 255 * 0.15),
      ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Map View')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: childPosition, zoom: 17),
        markers: markers,
        circles: circles,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
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