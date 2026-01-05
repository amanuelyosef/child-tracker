import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../config/app_constants.dart';
import '../services/background_service.dart';
import '../services/firestore_location_service.dart';
import '../services/location_service.dart';
import '../utils/date_formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/logout_dialog.dart';

/// Child mode screen for broadcasting location
class ChildModeScreen extends StatefulWidget {
  const ChildModeScreen({super.key});

  @override
  State<ChildModeScreen> createState() => _ChildModeScreenState();
}

class _ChildModeScreenState extends State<ChildModeScreen> {
  final String _pairCode = _generatePairCode();
  final LocationService _locationService = LocationService();
  final FirestoreLocationService _firestoreService = FirestoreLocationService();
  
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
    final hasPermission = await _locationService.ensureLocationPermission();
    if (!hasPermission) {
      setState(() => _status = 'Location permission denied');
      return;
    }
    
    final hasNotification = await _locationService.ensureNotificationPermission();
    if (!hasNotification) {
      setState(() => _status = 'Notification permission denied');
      return;
    }

    await ensureBackgroundServiceStarted();

    // Inform background service which pairing code to use and start tracking
    backgroundService.invoke('setPairCode', {'pairCode': _pairCode});
    backgroundService.invoke('startTracking');

    _positionSub?.cancel();
    _positionSub = _locationService.getPositionStream(
      distanceFilter: AppConstants.locationDistanceFilter,
    ).listen((pos) async {
      await _firestoreService.uploadPosition(_pairCode, pos);
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
    backgroundService.invoke('stopTracking');
    setState(() {
      _isStreaming = false;
      _status = 'Stopped sharing';
    });
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Mode - Location Sharing'),
        backgroundColor: Colors.blue.shade700,
        automaticallyImplyLeading: false,
        actions: const [LogoutButton()],
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
              // Header banner
              StatusBanner(
                title: 'Broadcasting to parent',
                subtitle: 'Keep this screen open to stay in sync.',
                icon: Icons.radar,
                gradientColors: [Colors.blue.shade600, Colors.teal.shade500],
                isActive: _isStreaming,
                activeLabel: 'Live',
                inactiveLabel: 'Idle',
              ),

              const SizedBox(height: 16),

              // Pairing code card
              GlassCard(
                child: Column(
                  children: [
                    Text(
                      'Share this code with parent',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Status card
              GlassCard(
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
                              Text(
                                _isStreaming ? 'Sharing Location' : 'Not Sharing',
                                style: titleStyle?.copyWith(
                                  color: _isStreaming ? Colors.green : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _status,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                          StatChip(
                            label: 'Updates sent',
                            value: _updateCount.toString(),
                          ),
                          StatChip(
                            label: 'Last update',
                            value: _lastUpdate != null 
                                ? formatTime(_lastUpdate!) 
                                : '--',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Control buttons
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

              // Tips card
              GlassCard(
                color: Colors.orange.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Tips for best accuracy',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
