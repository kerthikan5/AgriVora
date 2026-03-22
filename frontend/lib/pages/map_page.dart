/// **MapPage**
/// Responsible for: Rendering an interactive map (e.g. for farm bounds or sensor locations).
/// Dependency: flutter_map package.

import 'dart:async';
import 'dart:convert';
import 'dart:ui'
    show ImageFilter, Path; // explicit Path import beats latlong2's
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/location_service.dart';
import '../services/api_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  Position? _currentLocation;
  String _cityName = "Locating...";
  String _temperature = "--°C";
  String _rainfall = "--mm";
  String _humidity = "--%";
  final String _soilCondition = "Good";
  final String _soilType = "Reddish Brown Earth";
  bool _mapReady = false;
  bool _locationDenied = false;
  bool _showLiveLocationBanner = true;
  StreamSubscription<Position>? _positionStream;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _initData();
    // Hide the "Getting live location" overlay after 7 seconds if GPS takes too long
    _bannerTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        setState(() => _showLiveLocationBanner = false);
      }
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    _startLocationTracking();
    await _getUserLocation();
  }

  void _startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() => _currentLocation = position);
        if (_mapReady) {
          try {
            _mapController.move(
                LatLng(position.latitude, position.longitude), 16);
          } catch (_) {}
        }
      }
    }, onError: (e) => debugPrint("Location stream error: $e"));
  }

  void _recenterMap() {
    if (_currentLocation != null && _mapReady) {
      try {
        _mapController.move(
            LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
            16);
      } catch (_) {}
    } else {
      _getUserLocation();
    }
  }

  Future<void> _getUserLocation() async {
    // 1. Try last known for instant centering
    final lastPos = await Geolocator.getLastKnownPosition();
    if (lastPos != null && mounted) {
      setState(() => _currentLocation = lastPos);
      if (_mapReady) {
        try {
          _mapController.move(LatLng(lastPos.latitude, lastPos.longitude), 16);
        } catch (_) {}
      }
      // Fetch weather load immediately for this cached coordinate
      await _fetchWeatherData(lastPos);
    }

    try {
      final pos = await LocationService.getCurrentLocation()
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(() {
          _locationDenied = false;
          _currentLocation = pos;
        });
        if (_mapReady) {
          try {
            _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
          } catch (_) {}
        }
        await _fetchWeatherData(pos);
      }
    } catch (e) {
      debugPrint("Location fetch failed: $e");
      if (e.toString().toLowerCase().contains("denied")) {
        if (mounted) setState(() => _locationDenied = true);
        return;
      }
      // Fallback to medium accuracy
      try {
        final fallbackPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        ).timeout(const Duration(seconds: 8));
        if (mounted) {
          setState(() {
            _locationDenied = false;
            _currentLocation = fallbackPos;
          });
          await _fetchWeatherData(fallbackPos);
        }
      } catch (fallbackE) {
        if (fallbackE.toString().toLowerCase().contains("denied")) {
          if (mounted) setState(() => _locationDenied = true);
        }
      }
    }
  }

  Future<void> _fetchWeatherData([Position? pos]) async {
    final location = pos ?? _currentLocation;
    if (location == null) return;
    final lat = location.latitude;
    final lon = location.longitude;

    // ── Try backend first ──────────────────────────────────────────────────
    try {
      final summary = await ApiService.getLocationSummary(lat, lon)
          .timeout(const Duration(seconds: 8));
      final weather = summary['weatherSummary'];
      if (mounted && weather != null && weather['temperature'] != null) {
        setState(() {
          _temperature = "${weather['temperature'] ?? '--'}°C";
          _rainfall = "${weather['rainfall'] ?? '--'}mm";
          _humidity = "${weather['humidity'] ?? '--'}%";
          _cityName = summary['location'] ?? "My Fields";
        });
        return; // success — done
      }
    } catch (e) {
      debugPrint("Backend weather failed, falling back to direct APIs: $e");
    }

    // ── Fallback: call Open-Meteo + Nominatim directly ─────────────────────
    await _fetchWeatherDirect(lat, lon);
  }

  Future<void> _fetchWeatherDirect(double lat, double lon) async {
    // Open-Meteo (free, no key)
    try {
      final url = Uri.parse('https://api.open-meteo.com/v1/forecast'
          '?latitude=$lat&longitude=$lon'
          '&current=temperature_2m,relative_humidity_2m,precipitation'
          '&timezone=auto');
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final current = data['current'] ?? {};
        if (mounted) {
          setState(() {
            _temperature = "${current['temperature_2m'] ?? '--'}°C";
            _rainfall = "${current['precipitation'] ?? '--'}mm";
            _humidity = "${current['relative_humidity_2m'] ?? '--'}%";
          });
        }
      }
    } catch (e) {
      debugPrint("Open-Meteo direct call failed: $e");
    }

    // Nominatim reverse geocoding (free, no key)
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse'
          '?format=json&lat=$lat&lon=$lon&zoom=10');
      final res = await http.get(url, headers: {
        'User-Agent': 'AgriVoraApp/1.0'
      }).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final address = data['address'] ?? {};
        final name = address['city'] ??
            address['town'] ??
            address['village'] ??
            address['county'] ??
            'My Fields';
        if (mounted) setState(() => _cityName = name);
      }
    } catch (e) {
      debugPrint("Nominatim direct call failed: $e");
      if (mounted) setState(() => _cityName = "My Fields");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5),
      body: Stack(
        children: [
          // 🌾 Background
          Positioned.fill(
            child:
                Image.asset('assets/images/bg_fields.png', fit: BoxFit.cover),
          ),

          // ✅ Top Header (Floating over the image)
          Positioned(
            top: MediaQuery.of(context).padding.top + 55,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Farm Location",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                    shadows: [
                      Shadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          offset: Offset(0, 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Real-time Soil & Weather Insights",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 1)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _cityName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                              color: Colors.black45,
                              blurRadius: 4,
                              offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Glass panel
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _MapWaveClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  height: size.height * 0.88,
                  padding: EdgeInsets.fromLTRB(16, 140, 16, bottomPad + 130),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2E8D5).withValues(alpha: 0.65),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Map ─────────────────────────────────────────────
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: Stack(
                              children: [
                                  // ── FlutterMap rendered unconditionally ─────────────────────
                                  FlutterMap(
                                    mapController: _mapController,
                                    options: MapOptions(
                                      initialCenter: LatLng(
                                          _currentLocation?.latitude ?? 6.9271,
                                          _currentLocation?.longitude ?? 79.8612),
                                      initialZoom: _currentLocation != null ? 16 : 10,
                                      onMapReady: () {
                                        setState(() => _mapReady = true);
                                      },
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName:
                                            'com.example.agrivora_ui_test',
                                      ),
                                      if (_currentLocation != null)
                                        MarkerLayer(
                                          markers: [
                                            Marker(
                                              point: LatLng(
                                                  _currentLocation!.latitude,
                                                  _currentLocation!.longitude),
                                              width: 60,
                                              height: 60,
                                              child: GestureDetector(
                                                onTap: () =>
                                                    _showDetailedSoilInsight(context),
                                                child: const Icon(
                                                  Icons.location_on,
                                                  color: Color(0xFFD32F2F),
                                                  size: 50,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),

                                  // ── Conditional Loading/Denied Banner Overlay ───────────────
                                  if (_currentLocation == null && _showLiveLocationBanner)
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black.withValues(
                                                    alpha: 0.1),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4))
                                          ],
                                        ),
                                        child: _locationDenied
                                            ? Row(
                                                children: [
                                                  const Icon(
                                                      Icons.location_off,
                                                      color: Color(0xFFD32F2F),
                                                      size: 24),
                                                  const SizedBox(width: 12),
                                                  const Expanded(
                                                    child: Text(
                                                        "Location access denied.",
                                                        style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD32F2F),
                                                        )),
                                                  ),
                                                  TextButton(
                                                      onPressed: _getUserLocation,
                                                      child: const Text("Enable",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32)))),
                                                ],
                                              )
                                            : Row(
                                                children: const [
                                                  SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Color(0xFF2E7D32),
                                                    ),
                                                  ),
                                                  SizedBox(width: 12),
                                                  Text("Getting live location…",
                                                      style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32))),
                                                ],
                                              ),
                                      ),
                                    ),

                                // Map Overlay Action Buttons
                                if (_currentLocation != null)
                                  Positioned(
                                    right: 12,
                                    top: 12,
                                    child: Column(
                                      children: [
                                        _buildMapActionButton(
                                            Icons.my_location, _recenterMap),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // ── Bottom Info Panel ───────────────────────────────
                      _buildBottomInfoCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Navigation Bar
        ],
      ),
    );
  }

  Widget _buildBottomInfoCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3EA).withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Soil Condition:",
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Color(0xFF1B1B1B))),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_soilCondition,
                        style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(Icons.thermostat, _temperature, "Temp"),
                  Container(width: 1, height: 30, color: Colors.black12),
                  _buildStat(Icons.water_drop, _rainfall, "Rain"),
                  Container(width: 1, height: 30, color: Colors.black12),
                  _buildStat(Icons.landscape, _soilType, "Soil Type"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapActionButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Icon(icon, color: const Color(0xFF2E7D32), size: 22),
      ),
    );
  }

  void _showDetailedSoilInsight(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: BoxDecoration(
                color: const Color(0xFFF2E8D5).withValues(alpha: 0.92),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Location Insights",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B1B1B))),
                  const SizedBox(height: 16),
                  _buildAnalysisRow("Estimated Soil Type:", _soilType),
                  const SizedBox(height: 10),
                  _buildAnalysisRow("Condition:", _soilCondition),
                  const SizedBox(height: 10),
                  _buildAnalysisRow("Region:", _cityName),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(context, '/crop-recommendation',
                            arguments: _soilType);
                      },
                      child: const Text("Get Crop Recommendation",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold))),
        Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2E7D32))),
      ],
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF2E7D32), size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1B1B1B)),
        ),
        Text(
          label,
          style: const TextStyle(
              fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Wave-shaped clipper for the glass panel
class _MapWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 115);
    path.quadraticBezierTo(size.width * 0.22, 35, size.width * 0.52, 98);
    path.quadraticBezierTo(size.width * 0.82, 160, size.width, 85);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
