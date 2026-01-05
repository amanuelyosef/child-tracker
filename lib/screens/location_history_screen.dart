import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_constants.dart';
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
      ),
      body: StreamBuilder<QuerySnapshot>(
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
              final timeStr = formatTime(dateTime);
              final dateStr = formatDate(dateTime);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                              radiusMeters: AppConstants.defaultSafeRadius,
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
