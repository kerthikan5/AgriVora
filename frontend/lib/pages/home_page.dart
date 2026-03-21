/// **HomePage**
/// Responsible for: The primary user dashboard.
/// Role: Displays user greeting, quick action buttons (Soil Analysis, Chat), and status cards.
/// Dependencies: Navigates to SoilAnalysisPage, AIChatPage, PredictSoilPage.

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/location_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _cityName = "Locating...";
  String _temperature = "--°C";
  String _rainfall = "--mm";

  @override
  void initState() {
    super.initState();
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      final lat = pos.latitude;
      final lon = pos.longitude;

      // ── Try backend first ──────────────────────────────────────────────
      try {
        final summary = await ApiService.getLocationSummary(lat, lon)
            .timeout(const Duration(seconds: 8));
        final weather = summary['weatherSummary'];
        if (mounted && weather != null) {
          setState(() {
            _temperature = "${weather['temperature'] ?? '--'}°C";
            _rainfall = "${weather['rainfall'] ?? '--'}mm";
            _cityName = summary['location'] ?? "My Fields";
          });
          return; // done
        }
      } catch (e) {
        debugPrint("Backend failed, using direct APIs: $e");
      }

      // ── Fallback: Open-Meteo (free, no API key) ────────────────────────
      try {
        final url = Uri.parse('https://api.open-meteo.com/v1/forecast'
            '?latitude=$lat&longitude=$lon'
            '&current=temperature_2m,precipitation'
            '&timezone=auto');
        final res = await http.get(url).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final current = data['current'] ?? {};
          if (mounted) {
            setState(() {
              _temperature = "${current['temperature_2m'] ?? '--'}°C";
              _rainfall = "${current['precipitation'] ?? '--'}mm";
            });
          }
        }
      } catch (e) {
        debugPrint("Open-Meteo direct call failed: $e");
      }

      // ── Fallback: Nominatim reverse geocoding ──────────────────────────
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
        debugPrint("Nominatim call failed: $e");
        if (mounted) setState(() => _cityName = "My Fields");
      }
    } catch (e) {
      if (mounted) setState(() => _cityName = "My Fields");
      debugPrint("Location error: $e");
    }
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final bool isGuest = ApiService.userId == null;
    final String displayName =
        isGuest ? "Guest" : (ApiService.userName?.split(' ')[0] ?? "Farmer");

    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5),
      body: Stack(
        children: [
          // 🌾 Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_fields.png',
              fit: BoxFit.cover,
            ),
          ),

          // ✅ Top Greeting (Floating over the image)
          Positioned(
            top: MediaQuery.of(context).padding.top + 55,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_getGreeting()}, $displayName",
                  style: const TextStyle(
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
                  "Here is your farm overview today",
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
              ],
            ),
          ),

          // ✅ Main Panel (Glass Background)
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _HomeWaveClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  height: size.height * 0.88,
                  padding: EdgeInsets.fromLTRB(16, 90, 16, bottomPad + 70),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2E8D5).withOpacity(0.68),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                  height: 20), // Push the top element lower
                              // 1. Weather / Location
                              _buildWeatherCard(size),
                              const SizedBox(height: 16),

                              // 2. 2x2 Grid Features
                              _buildGridFeatures(context),
                              const SizedBox(height: 16),

                              // 3. Insight Section
                              _buildInsightCard(),
                              const SizedBox(height: 16),

                              // 4. Geo-Based Soil Insight
                              _buildGeoInsightCard(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ✅ Bottom nav
        ],
      ),
    );
  }

  Widget _buildWeatherCard(Size size) {
    return SizedBox(
      height: 140,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _GlassCard(
              width: size.width * 0.62,
              height: 110,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Color(0xFF2E7D32), size: 18),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _cityName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1B1B1B),
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Metric(label: "Temp", value: _temperature),
                        _Metric(label: "Rain", value: _rainfall),
                        const _Metric(
                            label: "Humid",
                            value: "82%"), // Ideal farming baseline
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ✅ Robot
          Positioned(
            right: -10,
            bottom: -5,
            child: Image.asset(
              'assets/images/robot.png',
              height: 145,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridFeatures(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FeatureGridCard(
            icon: Icons.grass_rounded,
            title: "Crop Recom",
            subtitle: "AI suggestions",
            onTap: () => _showCropRecomChoiceSheet(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FeatureGridCard(
            icon: Icons.science_rounded,
            title: "Soil Analyze",
            subtitle: "Upload & scan",
            onTap: () => Navigator.pushNamed(context, '/soil-analysis'),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard() {
    return _GlassCard(
      width: double.infinity,
      height: 90,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lightbulb_outline_rounded,
                  color: Color(0xFF2E7D32), size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Today's Insight",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B5E20))),
                  SizedBox(height: 4),
                  Text(
                      "Rainfall expected later. Consider delaying irrigation to conserve water.",
                      style: TextStyle(
                          fontSize: 12, color: Colors.black87, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGeoInsightCard() {
    return _GlassCard(
      width: double.infinity,
      height: 120, // slightly shorter if space allows
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Color(0xFFD32F2F), size: 18),
                const SizedBox(width: 6),
                const Text("Location-Based Insight",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B1B1B))),
                const Spacer(),
                Text(_cityName,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2E7D32))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Common Soil: Reddish Brown Earth",
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B1B1B))),
                      SizedBox(height: 4),
                      Text("Best Seasonal Crops: Chili, Onion",
                          style:
                              TextStyle(fontSize: 12, color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Bottom sheet: choose how to get pH for Crop Recommendation
  void _showCropRecomChoiceSheet(BuildContext context) {
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
                color: const Color(0xFFF2E8D5).withOpacity(0.92),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
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
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Get Crop Recommendation",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Choose how you want to provide your soil pH:",
                    style: TextStyle(
                        fontSize: 13, color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  // Option 1: BLE Sensor
                  _ChoiceOption(
                    icon: Icons.bluetooth_connected,
                    iconColor: const Color(0xFF1565C0),
                    title: "Use BLE Soil Sensor",
                    subtitle:
                        "Connect to your ESP32 pH sensor for live readings",
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, '/soil-analysis',
                          arguments: {'mode': 'sensor'});
                    },
                  ),
                  const SizedBox(height: 12),
                  // Option 2: Manual Entry
                  _ChoiceOption(
                    icon: Icons.edit_note_rounded,
                    iconColor: const Color(0xFF2E7D32),
                    title: "Enter pH Manually",
                    subtitle:
                        "Type in your soil pH value to get recommendations",
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, '/manual-soil');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ✅ Choice option tile used in the bottom sheet
class _ChoiceOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3EA).withOpacity(0.65),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF004D40)),
          ],
        ),
      ),
    );
  }
}

/// ✅ Wavy clipper
class _HomeWaveClipper extends CustomClipper<Path> {
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

class _GlassCard extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  const _GlassCard({
    required this.width,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3EA).withOpacity(0.45),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1B1B1B),
          ),
        ),
      ],
    );
  }
}

class _FeatureGridCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureGridCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: _GlassCard(
        width: double.infinity,
        height: 110,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF2E7D32), size: 22),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B1B1B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1B1B1B))),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}
