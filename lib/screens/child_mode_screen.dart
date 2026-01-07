import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../config/app_constants.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/background_service.dart';
import '../services/firestore_location_service.dart';
import '../services/location_service.dart';
import '../services/user_service.dart';
import '../utils/date_formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/logout_dialog.dart';
import 'edit_profile_screen.dart';

class ChildModeScreen extends StatefulWidget {
  const ChildModeScreen({super.key});

  @override
  State<ChildModeScreen> createState() => _ChildModeScreenState();
}

class _ChildModeScreenState extends State<ChildModeScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  final _locationService = LocationService();
  final _firestoreService = FirestoreLocationService();

  ChildUser? _childUser;
  ParentUser? _parentUser;
  bool _isLoading = true;
  bool _isStreaming = false;
  StreamSubscription<Position>? _positionSub;
  String _status = 'Idle';
  int _updateCount = 0;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final child = await _authService.getCurrentChildUser();
    if (child == null) {
      setState(() => _isLoading = false);
      return;
    }
    ParentUser? parent;
    if (child.parentId != null) {
      parent = await _userService.getParentUser(child.parentId!);
    }
    setState(() {
      _childUser = child;
      _parentUser = parent;
      _isLoading = false;
    });
  }

  Future<void> _toggleTracking(bool enabled) async {
    if (_childUser == null) return;
    await _userService.setTrackingEnabled(childId: _childUser!.uid, enabled: enabled);
    if (!enabled && _isStreaming) {
      await _stopStreaming();
    }
    setState(() {
      _childUser = _childUser!.copyWith(isTrackingEnabled: enabled);
    });
  }

  Future<void> _startStreaming() async {
    if (_childUser == null) return;
    if (!_childUser!.isTrackingEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable tracking first')));
      return;
    }
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
    backgroundService.invoke('setPairCode', {'pairCode': _childUser!.pairCode});
    backgroundService.invoke('startTracking');
    _positionSub?.cancel();
    _positionSub = _locationService.getPositionStream(distanceFilter: AppConstants.locationDistanceFilter).listen((pos) async {
      await _firestoreService.uploadPosition(_childUser!.pairCode, pos);
      setState(() {
        _status = 'Sharing - updated ' + formatTime(DateTime.now());
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

  void _copyPairCode() {
    if (_childUser == null) return;
    Clipboard.setData(ClipboardData(text: _childUser!.pairCode));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('Child Mode'), backgroundColor: Colors.blue.shade700, automaticallyImplyLeading: false), body: const Center(child: CircularProgressIndicator()));
    }
    if (_childUser == null) {
      return Scaffold(appBar: AppBar(title: const Text('Child Mode'), backgroundColor: Colors.blue.shade700, automaticallyImplyLeading: false), body: const Center(child: Text('Error loading user data')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Mode'),
        backgroundColor: Colors.blue.shade700,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.person, color: Colors.white), onPressed: () async {
            final result = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EditProfileScreen(user: _childUser!)));
            if (result == true) _loadData();
          }, tooltip: 'Edit Profile'),
          const LogoutButton(),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatusBanner(title: 'Hello, ' + _childUser!.displayName, subtitle: _parentUser != null ? 'Connected to ' + _parentUser!.displayName : 'Not connected to a parent yet', icon: Icons.child_care, gradientColors: [Colors.blue.shade600, Colors.teal.shade500], isActive: _isStreaming, activeLabel: 'Live', inactiveLabel: 'Idle'),
                const SizedBox(height: 16),
                GlassCard(child: Column(children: [
                  Text('Your Permanent Pair Code', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
                  const SizedBox(height: 12),
                  SelectableText(_childUser!.pairCode, style: Theme.of(context).textTheme.displaySmall?.copyWith(letterSpacing: 4, fontWeight: FontWeight.w900, color: Colors.blue.shade800)),
                  const SizedBox(height: 8),
                  Text('Give this code to your parent to connect', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(onPressed: _copyPairCode, icon: const Icon(Icons.copy), label: const Text('Copy Code'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600)),
                ])),
                const SizedBox(height: 16),
                if (_parentUser != null) GlassCard(color: Colors.purple.shade50, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.family_restroom, color: Colors.purple.shade700, size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Connected Parent', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                      const SizedBox(height: 4),
                      Text(_parentUser!.displayName, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text(_parentUser!.email, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                    ])),
                  ]),
                ])),
                const SizedBox(height: 16),
                GlassCard(child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      Icon(_childUser!.isTrackingEnabled ? Icons.location_on : Icons.location_off, color: _childUser!.isTrackingEnabled ? Colors.green : Colors.grey, size: 28),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Location Tracking', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        Text(_childUser!.isTrackingEnabled ? 'Parent can see your location' : 'Location sharing disabled', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                      ]),
                    ]),
                    Switch(value: _childUser!.isTrackingEnabled, onChanged: _toggleTracking, activeColor: Colors.green),
                  ]),
                ])),
                const SizedBox(height: 16),
                if (_childUser!.isTrackingEnabled) GlassCard(color: _isStreaming ? Colors.green.shade50 : Colors.grey.shade100, child: Column(children: [
                  Row(children: [
                    Icon(_isStreaming ? Icons.sensors : Icons.sensors_off, color: _isStreaming ? Colors.green : Colors.grey, size: 32),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_isStreaming ? 'Broadcasting Location' : 'Not Broadcasting', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: _isStreaming ? Colors.green : Colors.grey)),
                      const SizedBox(height: 4),
                      Text(_status, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ])),
                  ]),
                  if (_isStreaming) ...[
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      StatChip(label: 'Updates sent', value: _updateCount.toString()),
                      StatChip(label: 'Last update', value: _lastUpdate != null ? formatTime(_lastUpdate!) : '--'),
                    ]),
                  ],
                ])),
                if (_childUser!.isTrackingEnabled) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: ElevatedButton.icon(onPressed: _isStreaming ? null : _startStreaming, icon: const Icon(Icons.play_arrow), label: const Text('Start'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: Colors.green.shade600, disabledBackgroundColor: Colors.grey.shade400))),
                    const SizedBox(width: 12),
                    Expanded(child: OutlinedButton.icon(onPressed: _isStreaming ? _stopStreaming : null, icon: const Icon(Icons.stop), label: const Text('Stop'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)))),
                  ]),
                ],
                const SizedBox(height: 16),
                GlassCard(color: Colors.orange.shade50, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.info, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text('Tips', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text(' Share your code with your parent\n Keep the app open for real-time updates\n Toggle tracking off to stop sharing location\n Your code stays the same - no need to re-share', style: Theme.of(context).textTheme.bodySmall),
                ])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
