/// **CropRecomPage**
/// Responsible for: Displaying crop recommendations.
/// Role: Receives recommendation results and displays ranked list of crops suitable for the analyzed soil.
/// Navigation: Pushed after LightGBM or Random Forest API calls succeed.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class CropRecomPage extends StatefulWidget {
  const CropRecomPage({super.key});

  @override
  State<CropRecomPage> createState() => _CropRecomPageState();
}

class _CropRecomPageState extends State<CropRecomPage> {
  bool _isLoading = true;
  String? _errorMsg;
  Map<String, dynamic>? _prediction;
  Map<String, dynamic>? _args;
  bool _initialized = false;

  String _loadingState = "Fetching location and weather data...";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _args = args;
      _runPrediction(args ?? <String, dynamic>{});
      _initialized = true;
    }
  }

  Future<void> _runPrediction(Map<String, dynamic> data) async {
    try {
      setState(() => _loadingState = "Getting local weather...");

      double? temp, humid, rain, carbon;
      try {
        final pos = await LocationService.getCurrentLocation();
        final summary =
            await ApiService.getLocationSummary(pos.latitude, pos.longitude);

        final weather = summary['weatherSummary'] ?? {};
        final soil = summary['soilSummary'] ?? {};

        temp = (weather['temperature'] as num?)?.toDouble();
        humid = (weather['humidity'] as num?)?.toDouble();
        rain = (weather['rainfall'] as num?)?.toDouble();

        carbon = (soil['organicCarbon'] as num?)?.toDouble() ??
            (soil['soc'] as num?)?.toDouble();
      } catch (e) {
        debugPrint("Location/Weather fetch failed: $e");
      }

      setState(() => _loadingState = "Analyzing data with AI...");

      final res = await ApiService.predictCropLGBM(
        temperature: (data['temperature'] != null)
            ? data['temperature'].toDouble()
            : (temp ?? 27.0),
        humidity: (data['humidity'] != null)
            ? data['humidity'].toDouble()
            : (humid ?? 75.0),
        rainfall: (data['rainfall'] != null)
            ? data['rainfall'].toDouble()
            : (rain ?? 100.0),
        ph: (data['ph'] ?? 6.5).toDouble(),
        nitrogen:
            (data['nitrogen'] != null) ? data['nitrogen'].toDouble() : 40.0,
        carbon: (data['carbon'] != null)
            ? data['carbon'].toDouble()
            : (carbon ?? 1.2),
        soilType: data['soilType']?.toString() ?? 'loamy soil',
      );

      if (mounted) {
        setState(() {
          _prediction = res;
          _isLoading = false;
        });

        ApiService.saveToHistory({
          "crop": res['recommended_crop'] ?? res['crop'] ?? 'Unknown',
          "confidence": res['confidence'] ?? 0.85,
          "ph": (data['ph'] ?? 6.5).toDouble(),
          "temperature": (data['temperature']?.toDouble()) ?? (temp ?? 27.0),
          "humidity": (data['humidity']?.toDouble()) ?? (humid ?? 75.0),
          "rainfall": (data['rainfall']?.toDouble()) ?? (rain ?? 100.0),
          "soil_type": data['soilType']?.toString() ?? 'loamy soil',
          "type": "Crop Recommendation (LightGBM)"
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString().replaceFirst("Exception: ", "");
          _isLoading = false;
        });
      }
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
          // Background Imagery
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_fields.png',
              fit: BoxFit.cover,
            ),
          ),

          // Floating Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 55,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Recommendations",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                          shadows: [
                            Shadow(
                                color: Colors.black45,
                                blurRadius: 10,
                                offset: Offset(0, 2))
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "AI-Based Smart Farming Suggestions",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                                color: Colors.black45,
                                blurRadius: 8,
                                offset: Offset(0, 1))
                          ],
                        ),
                      ),
                      if (_args != null && _args!['ph'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "pH: ${(_args!['ph'] as double).toStringAsFixed(1)} | ${_args!['soilType'] ?? 'Loamy Soil'}",
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.eco_rounded,
                      color: Colors.white, size: 28),
                ),
              ],
            ),
          ),

          // Wavy Glass Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _RecomWaveClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  height: size.height * 0.88,
                  padding: EdgeInsets.fromLTRB(16, 120, 16, bottomPad + 70),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2E8D5).withValues(alpha: 0.68),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: _buildBody(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF2E7D32)),
            const SizedBox(height: 16),
            Text(_loadingState,
                style: const TextStyle(
                    color: Colors.black54, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
            const SizedBox(height: 16),
            const Text("Prediction Failed",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            Text(_errorMsg!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20))),
              child:
                  const Text("Go Back", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      );
    }

    if (_prediction == null) {
      return _buildEmptyState();
    }

    List<dynamic> recommendations = [];
    if (_prediction!.containsKey('recommendations') &&
        _prediction!['recommendations'] is List) {
      recommendations = _prediction!['recommendations'];
    }

    if (recommendations.isEmpty) {
      final cropName =
          _prediction!['recommended_crop'] ?? _prediction!['crop'] ?? "Unknown";
      final conf = _prediction!['confidence'] ?? 0.85;
      recommendations = [
        {"crop": cropName, "confidence": conf}
      ];
    }

    final topRec = recommendations.first;
    final otherRecs =
        recommendations.skip(1).take(3).toList(); // Up to 3 alternatives

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSmartDataStrip(),
          const SizedBox(height: 20),
          _buildPrimaryCropCard(topRec),
          if (otherRecs.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text("Alternative Options",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B1B1B))),
            const SizedBox(height: 12),
            ...otherRecs.map((rec) => _buildSecondaryCropCard(rec)),
          ],
          const SizedBox(height: 24),
          _buildSoilImprovementTips(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                shape: BoxShape.circle),
            child: const Icon(Icons.grass_rounded,
                size: 50, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 16),
          const Text("No Recommendations Yet",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1B))),
          const SizedBox(height: 8),
          const Text("Analyze soil to generate smart\ncrop suggestions.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSmartDataStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.auto_awesome, size: 14, color: Color(0xFF2E7D32)),
          SizedBox(width: 8),
          Flexible(
            child: Text("Based on Soil Data • AI Prediction",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32))),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryCropCard(dynamic rec) {
    final cropName = rec['crop']?.toString() ?? "Unknown";
    final conf = rec['confidence'] ?? 0.85;
    final double score = (conf is num) ? conf.toDouble() : 0.85;

    String condition = "Moderate Suitability";
    Color condColor = const Color(0xFFF57C00);
    if (score >= 0.70) {
      condition = "Highly Suitable";
      condColor = const Color(0xFF2E7D32);
    } else if (score < 0.40) {
      condition = "Needs Improvement";
      condColor = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: condColor.withValues(alpha: 0.15),
                child: Icon(Icons.spa_rounded, color: condColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cropName,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1B5E20))),
                    const SizedBox(height: 2),
                    Text(condition,
                        style: TextStyle(
                            fontSize: 12,
                            color: condColor,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Suitability Score",
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54)),
              Text("${(score * 100).toInt()}% Match",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: condColor)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: score,
              backgroundColor: Colors.black12,
              color: condColor,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFF2E7D32), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      "AI models indicate that $cropName is structurally aligned with the current soil profile and location climate factors.",
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF1B5E20), height: 1.4)),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/crop_overview', arguments: {
                      'name': cropName,
                      'image': 'assets/images/${cropName.toLowerCase()}.png',
                      'scientific': '$cropName Species'
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("View Crop Overview",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.bookmark_border_rounded,
                      color: Color(0xFF2E7D32)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Saved to history")));
                  },
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryCropCard(dynamic rec) {
    final cropName = rec['crop']?.toString() ?? "Unknown";
    final conf = rec['confidence'] ?? 0.85;
    final double score = (conf is num) ? conf.toDouble() : 0.85;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3EA).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.1),
            child: const Icon(Icons.eco_rounded,
                color: Color(0xFF2E7D32), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cropName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B5E20))),
                const Text("Alternative Option",
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${(score * 100).toInt()}%",
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2E7D32))),
              const Text("Match",
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSoilImprovementTips() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_rounded,
                  color: Color(0xFFF57C00)),
              const SizedBox(width: 8),
              const Text("Soil Improvement Tips",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1B1B))),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipRow("Adjust pH Levels",
              "Balance acidity explicitly for optimal root absorption", true),
          _buildTipRow("Improve Nitrogen Output",
              "Add organic compost to strengthen vegetative growth", false),
          _buildTipRow("Utilize N-P-K Formula",
              "Look into adding specialized multi-tiered fertilizer", false),
        ],
      ),
    );
  }

  Widget _buildTipRow(String title, String subtitle, bool highPriority) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: highPriority ? Colors.redAccent : const Color(0xFF2E7D32),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1B1B))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecomWaveClipper extends CustomClipper<Path> {
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
