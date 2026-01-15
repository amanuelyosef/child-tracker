import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Service for converting coordinates to human-readable addresses
class GeocodingService {
  /// Singleton pattern
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  /// Cache for addresses to reduce API calls
  final Map<String, String> _addressCache = {};

  /// Get a human-readable address from coordinates
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    // Create cache key with reduced precision (about 11 meters)
    final cacheKey = '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    
    // Check cache first
    if (_addressCache.containsKey(cacheKey)) {
      return _addressCache[cacheKey]!;
    }

    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = _formatAddress(place);
        
        // Cache the result
        _addressCache[cacheKey] = address;
        return address;
      }
    } catch (e) {
      // If geocoding fails, return formatted coordinates
      return _formatCoordinates(latitude, longitude);
    }
    
    return _formatCoordinates(latitude, longitude);
  }

  /// Format a Placemark into a readable address string
  String _formatAddress(Placemark place) {
    final parts = <String>[];
    
    // Add street name or thoroughfare
    if (place.street != null && place.street!.isNotEmpty) {
      parts.add(place.street!);
    } else if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
      parts.add(place.thoroughfare!);
    }
    
    // Add sub-locality (neighborhood) if different from street
    if (place.subLocality != null && 
        place.subLocality!.isNotEmpty && 
        !parts.contains(place.subLocality)) {
      parts.add(place.subLocality!);
    }
    
    // Add locality (city)
    if (place.locality != null && place.locality!.isNotEmpty) {
      parts.add(place.locality!);
    } else if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      parts.add(place.administrativeArea!);
    }
    
    // If we have parts, join them
    if (parts.isNotEmpty) {
      return parts.take(3).join(', '); // Limit to 3 parts for readability
    }
    
    // Fallback to name if available
    if (place.name != null && place.name!.isNotEmpty) {
      return place.name!;
    }
    
    return 'Unknown location';
  }

  /// Format coordinates into a readable string (fallback)
  String _formatCoordinates(double latitude, double longitude) {
    final latDir = latitude >= 0 ? 'N' : 'S';
    final lngDir = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(4)}°$latDir, ${longitude.abs().toStringAsFixed(4)}°$lngDir';
  }

  /// Calculate distance between two points in meters
  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Clear the address cache
  void clearCache() {
    _addressCache.clear();
  }
}
