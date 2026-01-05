import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_constants.dart';
import '../services/location_service.dart';

/// Map view screen for displaying child and parent locations
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
  final LocationService _locationService = LocationService();
  
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
        .collection(AppConstants.locationsCollection)
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

      // Keep the camera centered on the child unless the user moves it
      if (_cameraFollowingChild && _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(newPos));
      }
    });
  }

  Future<void> _listenToParentLocation() async {
    final hasPermission = await _locationService.ensureLocationPermission();
    if (!hasPermission) return;

    _parentPosSub = _locationService.getPositionStream(
      distanceFilter: AppConstants.parentLocationDistanceFilter,
    ).listen((pos) {
      setState(() {
        _parentPosition = LatLng(pos.latitude, pos.longitude);
      });
    });
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
                _mapController!.animateCamera(
                  CameraUpdate.newLatLng(_childPosition!),
                );
              },
        label: const Text('Center on Child'),
        icon: const Icon(Icons.my_location),
      ),
    );
  }
}
