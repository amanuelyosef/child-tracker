import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_constants.dart';
import '../services/geocoding_service.dart';
import '../utils/date_formatters.dart';
import 'map_view_screen.dart';

/// Location history screen showing past locations
class LocationHistoryScreen extends StatefulWidget {
  const LocationHistoryScreen({super.key, required this.pairCode});

  final String pairCode;

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  late CollectionReference _historyRef;
  final GeocodingService _geocodingService = GeocodingService();

  @override
  void initState() {
    super.initState();
    _historyRef = FirebaseFirestore.instance
        .collection(AppConstants.locationsCollection)
        .doc(widget.pairCode)
        .collection(AppConstants.historySubcollection);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location History'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade50, Colors.white],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _historyRef
              .orderBy('timestamp', descending: true)
              .limit(AppConstants.maxHistoryItems)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No location history yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Location history is saved every 50 meters',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            final docs = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final lat = (data['latitude'] as num?)?.toDouble() ?? 0;
                final lng = (data['longitude'] as num?)?.toDouble() ?? 0;
                final timestamp = data['timestamp'] as Timestamp?;
                final savedAddress = data['address'] as String?;
                
                final dateTime = timestamp?.toDate() ?? DateTime.now();
                final timeStr = formatTime(dateTime);
                final dateStr = formatDate(dateTime);

                return _LocationHistoryItem(
                  latitude: lat,
                  longitude: lng,
                  dateStr: dateStr,
                  timeStr: timeStr,
                  savedAddress: savedAddress,
                  geocodingService: _geocodingService,
                  pairCode: widget.pairCode,
                  isFirst: index == 0,
                  isLast: index == docs.length - 1,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Individual location history item with address loading
class _LocationHistoryItem extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String dateStr;
  final String timeStr;
  final String? savedAddress;
  final GeocodingService geocodingService;
  final String pairCode;
  final bool isFirst;
  final bool isLast;

  const _LocationHistoryItem({
    required this.latitude,
    required this.longitude,
    required this.dateStr,
    required this.timeStr,
    required this.savedAddress,
    required this.geocodingService,
    required this.pairCode,
    required this.isFirst,
    required this.isLast,
  });

  @override
  State<_LocationHistoryItem> createState() => _LocationHistoryItemState();
}

class _LocationHistoryItemState extends State<_LocationHistoryItem> {
  String? _address;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Use saved address if available, otherwise fetch it
    if (widget.savedAddress != null && widget.savedAddress!.isNotEmpty) {
      _address = widget.savedAddress;
    } else {
      _loadAddress();
    }
  }

  Future<void> _loadAddress() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    
    try {
      final address = await widget.geocodingService.getAddressFromCoordinates(
        widget.latitude,
        widget.longitude,
      );
      if (mounted) {
        setState(() {
          _address = address;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _address = '${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isFirst ? Colors.teal : Colors.teal.shade300,
                  border: Border.all(color: Colors.teal.shade700, width: 2),
                ),
              ),
              if (!widget.isLast)
                Container(
                  width: 2,
                  height: 70,
                  color: Colors.teal.shade200,
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content card
          Expanded(
            child: Card(
              elevation: widget.isFirst ? 4 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: widget.isFirst 
                    ? BorderSide(color: Colors.teal.shade300, width: 1)
                    : BorderSide.none,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MapViewScreen(
                        childPosition: LatLng(widget.latitude, widget.longitude),
                        radiusMeters: AppConstants.defaultSafeRadius,
                        pairCode: widget.pairCode,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time and date row
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.timeStr,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.dateStr,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          if (widget.isFirst)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Latest',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Address row
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 18,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _isLoading
                                ? Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Loading address...',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    _address ?? 'Unknown location',
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
