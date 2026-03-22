/// **LocationService**
/// Responsible for: Geographic location acquisition.
/// Role: Getting current lat/lon safely using geolocator.

import 'package:geolocator/geolocator.dart';

class LocationService {
  static Position? latestPosition;

  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are OFF on device/emulator.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception("Location permission denied.");
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          "Location permission denied forever. Enable from settings.");
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    latestPosition = pos; // Cache the position globally for immediate access on other screens
    return pos;
  }
}
