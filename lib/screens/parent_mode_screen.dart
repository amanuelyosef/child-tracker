import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_constants.dart';
import '../services/location_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/logout_dialog.dart';
import 'map_view_screen.dart';
import 'location_history_screen.dart';

/// Parent mode screen for monitoring child location
class ParentModeScreen extends StatefulWidget {
  const ParentModeScreen({super.key});

  @override
  State<ParentModeScreen> createState() => _ParentModeScreenState();
}

class _ParentModeScreenState extends State<ParentModeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final LocationService _locationService = LocationService();
  
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _childSub;
  StreamSubscription<Position>? _parentPositionSub;
  
  double _radiusMeters = AppConstants.defaultSafeRadius;
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

    final hasPermission = await _locationService.ensureLocationPermission();
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
    _parentPositionSub = _locationService.getPositionStream(
      distanceFilter: AppConstants.parentLocationDistanceFilter,
    ).listen((parentPos) {
      if (_childLatLng != null) {
        _updateDistance(parentPos);
      } else {
        setState(() => _parentPosition = parentPos);
      }
    });

    // Listen to child's location updates
    _childSub = FirebaseFirestore.instance
        .collection(AppConstants.locationsCollection)
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
        final distance = _locationService.calculateDistance(
          startLat: _lastChildLatLng!.latitude,
          startLng: _lastChildLatLng!.longitude,
          endLat: childLat,
          endLng: childLng,
        );
        final now = DateTime.now();
        final timeDiff = now.difference(_lastChildUpdate!).inSeconds;
        if (timeDiff > 0) {
          _lastSpeed = _locationService.calculateSpeed(
            distanceMeters: distance,
            timeSeconds: timeDiff,
          );
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
    
    final distance = _locationService.calculateDistance(
      startLat: parentPos.latitude,
      startLng: parentPos.longitude,
      endLat: _childLatLng!.latitude,
      endLng: _childLatLng!.longitude,
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAlerting = (_latestDistance ?? 0) > _radiusMeters;
    final speedText = _lastSpeed != null ? _lastSpeed!.toStringAsFixed(1) : '--';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Mode'),
        backgroundColor: Colors.blue.shade700,
        automaticallyImplyLeading: false,
        actions: const [LogoutButton()],
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
              // Header banner
              StatusBanner(
                title: 'Monitor your child live',
                subtitle: 'Connect with the code to begin tracking.',
                icon: Icons.map_outlined,
                gradientColors: [Colors.teal.shade600, Colors.blue.shade500],
                isActive: _isListening,
                activeLabel: 'Listening',
                inactiveLabel: 'Disconnected',
              ),

              const SizedBox(height: 16),

              // Connection card (shown when not listening)
              if (!_isListening)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connect to Child',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _codeController,
                        enabled: !_isListening,
                        decoration: InputDecoration(
                          labelText: 'Enter child pairing code',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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

              // Status and controls (shown when listening)
              if (_isListening) ...[
                GlassCard(
                  color: isAlerting ? Colors.red.shade50 : Colors.green.shade50,
                  child: Row(
                    children: [
                      Icon(
                        isAlerting ? Icons.warning_amber : Icons.shield,
                        color: isAlerting ? Colors.red : Colors.green,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _status,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isAlerting ? Colors.red : Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Code: $_linkedCode',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Distance and speed metrics
                if (_latestDistance != null)
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: 'Distance',
                          value: _latestDistance!.toStringAsFixed(0),
                          unit: 'm',
                          icon: Icons.straighten,
                          color: isAlerting ? Colors.red : Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricCard(
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

                // Safe radius slider
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Safe Radius',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_radiusMeters.toStringAsFixed(0)} m',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        min: AppConstants.minSafeRadius,
                        max: AppConstants.maxSafeRadius,
                        divisions: 19,
                        value: _radiusMeters,
                        onChanged: (value) => setState(() => _radiusMeters = value),
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Map view button
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
                                  : LatLng(
                                      _parentPosition!.latitude,
                                      _parentPosition!.longitude,
                                    ),
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

                // History button
                if (_linkedCode != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LocationHistoryScreen(
                              pairCode: _linkedCode!,
                            ),
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

                // Stop monitoring button
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
