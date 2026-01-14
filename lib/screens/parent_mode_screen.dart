import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_constants.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/user_service.dart';
import '../widgets/common_widgets.dart';
import 'edit_profile_screen.dart';
import 'manage_children_screen.dart';
import 'map_view_screen.dart';
import 'location_history_screen.dart';

class ParentModeScreen extends StatefulWidget {
  const ParentModeScreen({super.key});

  @override
  State<ParentModeScreen> createState() => _ParentModeScreenState();
}

class _ParentModeScreenState extends State<ParentModeScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  final _locationService = LocationService();

  ParentUser? _parentUser;
  List<ChildUser> _children = [];
  ChildUser? _selectedChild;
  
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _childLocationSub;
  StreamSubscription<Position>? _parentPositionSub;
  
  double _radiusMeters = AppConstants.defaultSafeRadius;
  double? _latestDistance;
  double? _lastSpeed;
  LatLng? _childLatLng;
  LatLng? _lastChildLatLng;
  Position? _parentPosition;
  DateTime? _lastChildUpdate;
  String _status = 'Select a child to track';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _childLocationSub?.cancel();
    _parentPositionSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final parent = await _authService.getCurrentParentUser();
    if (parent == null) {
      setState(() => _isLoading = false);
      return;
    }
    final children = await _userService.getChildrenForParent(parent.uid);
    setState(() {
      _parentUser = parent;
      _children = children;
      _isLoading = false;
    });
  }

  Future<void> _selectChild(ChildUser child) async {
    await _childLocationSub?.cancel();
    await _parentPositionSub?.cancel();
    setState(() {
      _selectedChild = child;
      _status = 'Connecting...';
      _latestDistance = null;
      _childLatLng = null;
      _lastChildLatLng = null;
      _lastSpeed = null;
    });
    if (!child.isTrackingEnabled) {
      setState(() => _status = child.displayName + ' has disabled tracking');
      return;
    }
    final hasPermission = await _locationService.ensureLocationPermission();
    if (!hasPermission) {
      setState(() => _status = 'Location permission denied');
      return;
    }
    _parentPositionSub = _locationService.getPositionStream(
      distanceFilter: AppConstants.parentLocationDistanceFilter,
    ).listen((parentPos) {
      if (_childLatLng != null) {
        _updateDistance(parentPos);
      } else {
        setState(() => _parentPosition = parentPos);
      }
    });
    _childLocationSub = FirebaseFirestore.instance
        .collection(AppConstants.locationsCollection)
        .doc(child.pairCode)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        setState(() => _status = 'Waiting for ' + child.displayName + ' to share location...');
        return;
      }
      final data = snapshot.data();
      if (data == null) return;
      final childLat = (data['latitude'] as num?)?.toDouble();
      final childLng = (data['longitude'] as num?)?.toDouble();
      if (childLat == null || childLng == null) return;
      final newChildLatLng = LatLng(childLat, childLng);
      if (_lastChildLatLng != null && _lastChildUpdate != null) {
        final distance = _locationService.calculateDistance(
          startLat: _lastChildLatLng!.latitude,
          startLng: _lastChildLatLng!.longitude,
          endLat: childLat,
          endLng: childLng,
        );
        final timeDiff = DateTime.now().difference(_lastChildUpdate!).inSeconds;
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
        _status = 'Tracking ' + child.displayName;
      });
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
      _status = distance > _radiusMeters 
          ? (_selectedChild?.displayName ?? '') + ' is out of range' 
          : (_selectedChild?.displayName ?? '') + ' is within range';
    });
  }

  void _stopTracking() {
    _childLocationSub?.cancel();
    _parentPositionSub?.cancel();
    setState(() {
      _selectedChild = null;
      _status = 'Select a child to track';
      _latestDistance = null;
      _childLatLng = null;
      _lastSpeed = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Parent Mode'), backgroundColor: Colors.teal.shade700, automaticallyImplyLeading: false),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final isTracking = _selectedChild != null;
    final isAlerting = (_latestDistance ?? 0) > _radiusMeters && isTracking;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Mode'),
        backgroundColor: Colors.teal.shade700,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: _parentUser == null
                ? null
                : () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _parentUser!)),
                    );
                    if (result == true) _loadData();
                  },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal.shade50, Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBanner(title: 'Welcome, ' + (_parentUser?.displayName ?? 'Parent'), subtitle: _children.isEmpty ? 'Add children to start tracking' : _children.length.toString() + ' child' + (_children.length == 1 ? '' : 'ren') + ' connected', icon: Icons.shield, gradientColors: [Colors.teal.shade600, Colors.blue.shade500], isActive: isTracking, activeLabel: 'Tracking', inactiveLabel: 'Idle'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ManageChildrenScreen()),
                      );
                      _loadData();
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Manage / Add Children'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_children.isEmpty)
                  GlassCard(child: Column(children: [
                    Icon(Icons.family_restroom, size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('No children connected', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Text('Add your child pair code to start tracking', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(onPressed: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageChildrenScreen())); _loadData(); }, icon: const Icon(Icons.person_add), label: const Text('Add a Child'), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
                  ]))
                else
                  GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Select Child to Track', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: _children.map((child) {
                      final isSelected = _selectedChild?.uid == child.uid;
                      return ChoiceChip(avatar: Icon(Icons.child_care, size: 18, color: isSelected ? Colors.white : Colors.blue.shade700), label: Text(child.displayName), selected: isSelected, onSelected: (_) { if (isSelected) { _stopTracking(); } else { _selectChild(child); } }, selectedColor: Colors.teal.shade600, backgroundColor: Colors.blue.shade50, labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.blue.shade700, fontWeight: FontWeight.bold));
                    }).toList()),
                    if (!isTracking) ...[const SizedBox(height: 8), Text('Tap a child name to start tracking', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600))],
                  ])),
                if (isTracking) ...[
                  const SizedBox(height: 16),
                  GlassCard(color: isAlerting ? Colors.red.shade50 : Colors.green.shade50, child: Row(children: [
                    Icon(isAlerting ? Icons.warning_amber : Icons.shield, color: isAlerting ? Colors.red : Colors.green, size: 30),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_status, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: isAlerting ? Colors.red : Colors.green))),
                  ])),
                  const SizedBox(height: 14),
                  if (_latestDistance != null) Row(children: [
                    Expanded(child: MetricCard(label: 'Distance', value: _latestDistance!.toStringAsFixed(0), unit: 'm', icon: Icons.straighten, color: isAlerting ? Colors.red : Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(child: MetricCard(label: 'Speed', value: _lastSpeed?.toStringAsFixed(1) ?? '--', unit: 'km/h', icon: Icons.speed, color: Colors.orange)),
                  ]),
                  const SizedBox(height: 14),
                  GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Safe Radius', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text(_radiusMeters.toStringAsFixed(0) + ' m', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ]),
                    Slider(min: AppConstants.minSafeRadius, max: AppConstants.maxSafeRadius, divisions: 19, value: _radiusMeters, onChanged: (value) => setState(() => _radiusMeters = value), activeColor: Colors.teal),
                  ])),
                  const SizedBox(height: 14),
                  if (_childLatLng != null) SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => MapViewScreen(childPosition: _childLatLng!, parentPosition: _parentPosition == null ? null : LatLng(_parentPosition!.latitude, _parentPosition!.longitude), radiusMeters: _radiusMeters, pairCode: _selectedChild!.pairCode))); }, icon: const Icon(Icons.map_outlined), label: const Text('View on Map'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Colors.purple))),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => LocationHistoryScreen(pairCode: _selectedChild!.pairCode))); }, icon: const Icon(Icons.history), label: const Text('View Location History'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Colors.blue.shade600))),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _stopTracking, icon: const Icon(Icons.stop), label: const Text('Stop Tracking'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
