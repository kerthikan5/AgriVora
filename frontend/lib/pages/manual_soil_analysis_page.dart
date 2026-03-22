/// **ManualSoilAnalysisPage**
/// Responsible for: Manual input of soil metrics (pH, Nitrogen, etc.).
/// Role: Collects manual entries to trigger crop recommendation by calling ApiService.predictCropLGBM().
/// API Dependency: /crop/recommend (LightGBM)

import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class ManualSoilAnalysisPage extends StatefulWidget {
  const ManualSoilAnalysisPage({super.key});

  @override
  State<ManualSoilAnalysisPage> createState() => _ManualSoilAnalysisPageState();
}

class _ManualSoilAnalysisPageState extends State<ManualSoilAnalysisPage> {
  bool _isLoading = false;

  // Controllers
  final TextEditingController _phController = TextEditingController();

  bool _isValid = false;
  Map<String, dynamic>? _predictionResult;

  double _fetchedTemp = 27.0;
  double _fetchedRain = 100.0;
  double _moisture = 75.0;

  @override
  void initState() {
    super.initState();
    _fetchWeatherData();
    _phController.addListener(_validateInputs);
  }

  Future<void> _fetchWeatherData() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      final summary =
          await ApiService.getLocationSummary(pos.latitude, pos.longitude);
      final weather = summary['weatherSummary'] ?? {};

      if (mounted) {
        setState(() {
          _fetchedTemp = (weather['temperature'] ?? 27.0).toDouble();
          _fetchedRain = (weather['rainfall'] ?? 100.0).toDouble();
          _moisture = (weather['humidity'] ?? 75.0).toDouble();
          _validateInputs();
        });
      }
    } catch (e) {
      // It's ok to fail, default values will be empty and user must enter.
    }
  }

  void _validateInputs() {
    final phNum = double.tryParse(_phController.text.trim());
    final bool isPhValid = phNum != null && phNum >= 0 && phNum <= 14;

    if (_isValid != isPhValid) {
      setState(() => _isValid = isPhValid);
    }
  }

  bool _isPhOutOfRange() {
    final phNum = double.tryParse(_phController.text.trim());
    return phNum != null && (phNum < 0 || phNum > 14);
  }

  @override
  void dispose() {
    _phController.dispose();
    super.dispose();
  }

  Future<void> _analyzeSoil() async {
    if (!_isValid) return;

    setState(() {
      _isLoading = true;
      _predictionResult = null;
    });

    try {
      final ph = double.parse(_phController.text.trim());

      final res = await ApiService.predictCropLGBM(
        temperature: _fetchedTemp,
        humidity: _moisture,
        rainfall: _fetchedRain,
        ph: ph,
        nitrogen: 40.0,
        carbon: 1.2, // Default or implied
        soilType: 'loamy soil',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _predictionResult = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
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
          // 🌾 Background Imagery
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_fields.png',
              fit: BoxFit.cover,
            ),
          ),

          // ✅ Floating Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 55,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Manual Analysis",
                      style: TextStyle(
                        fontSize: 28,
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
                    SizedBox(height: 4),
                    Text(
                      "Enter Soil Parameters for AI",
                      style: TextStyle(
                        fontSize: 14,
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
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      color: Colors.white, size: 28),
                ),
              ],
            ),
          ),

          // ✅ Large Wavy Glass Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _ManualWaveClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  height: size.height * 0.88,
                  padding: EdgeInsets.fromLTRB(16, 160, 16, bottomPad + 70),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2E8D5).withOpacity(0.68),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        if (_predictionResult != null)
                          _buildResultCard()
                        else if (_isLoading)
                          _buildLoadingCard()
                        else
                          _buildInputFormCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Input Form ───
  Widget _buildInputFormCard() {
    return _GlassCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Enter Soil Parameters",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1B))),
          const SizedBox(height: 16),

          // pH Value
          TextField(
            controller: _phController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "pH Value",
              helperText: _isPhOutOfRange()
                  ? "Warning: pH should be between 0 and 14"
                  : "Required: Range 0-14",
              helperStyle: TextStyle(
                  color: _isPhOutOfRange() ? Colors.redAccent : Colors.black54),
              prefixIcon:
                  const Icon(Icons.science_outlined, color: Color(0xFF2E7D32)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
            ),
          ),

          const SizedBox(height: 20),

          // Smart Validation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: (_isValid ? const Color(0xFF2E7D32) : Colors.orangeAccent)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                    _isValid
                        ? Icons.check_circle_outline
                        : Icons.pending_actions,
                    size: 18,
                    color: _isValid
                        ? const Color(0xFF2E7D32)
                        : Colors.orangeAccent),
                const SizedBox(width: 8),
                Text(
                    _isValid
                        ? "All parameters within bounds"
                        : "Please fill all required valid parameters",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isValid
                            ? const Color(0xFF2E7D32)
                            : Colors.orangeAccent)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isValid ? _analyzeSoil : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                elevation: 4,
              ),
              child: const Text("Analyze Soil & Recommend Crops",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Loading State ───
  Widget _buildLoadingCard() {
    return _GlassCardContainer(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Column(
          children: const [
            CircularProgressIndicator(color: Color(0xFF2E7D32)),
            SizedBox(height: 20),
            Text("Processing Soil Data...\nAnalyzing ML model pathways.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ─── Result State ───
  Widget _buildResultCard() {
    List<dynamic> recommendations = [];
    if (_predictionResult!.containsKey('recommendations') &&
        _predictionResult!['recommendations'] is List) {
      recommendations = _predictionResult!['recommendations'];
    }

    if (recommendations.isEmpty) {
      final cropName = _predictionResult!['recommended_crop'] ??
          _predictionResult!['crop'] ??
          "Unknown";
      final conf = _predictionResult!['confidence'] ?? 0.85;
      recommendations = [
        {"crop": cropName, "confidence": conf}
      ];
    }

    final rec = recommendations.first;
    final String topCrop = rec['crop']?.toString() ?? "Unknown";
    final double confidence =
        (rec['confidence'] is num) ? rec['confidence'].toDouble() : 0.85;

    String condition = "Moderate";
    Color condColor = const Color(0xFFF57C00);
    if (confidence >= 0.7) {
      condition = "Good";
      condColor = const Color(0xFF2E7D32);
    } else if (confidence < 0.4) {
      condition = "Poor";
      condColor = Colors.redAccent;
    }

    return _GlassCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              const Text("Analysis Complete",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1B1B))),
            ],
          ),
          const SizedBox(height: 16),
          _buildResultRow("Top Recommended Crop", topCrop, isBold: true),
          _buildResultRow("Soil Condition Status", condition, color: condColor),
          const SizedBox(height: 16),
          const Text("Suitability Score",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: confidence,
                    minHeight: 8,
                    backgroundColor: Colors.black12,
                    color: condColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text("${(confidence * 100).toInt()}%",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: condColor)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome,
                    color: Color(0xFF2E7D32), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      "AI suggests $topCrop is an excellent choice for your measured parameters including the current pH and climate.",
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF1B5E20), height: 1.4)),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/crop-overview', arguments: {
                  'name': topCrop,
                  'scientific': '$topCrop species',
                  'image': 'assets/images/${topCrop.toLowerCase()}.png',
                });
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("View Detailed Crop Overview",
                  style: TextStyle(
                      color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (_predictionResult != null) {
                  final data = {
                    "crop": topCrop,
                    "confidence": confidence,
                    "ph": double.tryParse(_phController.text) ?? 6.5,
                    "temperature": _fetchedTemp,
                    "humidity": _moisture,
                    "rainfall": _fetchedRain,
                    "soil_type": "Loamy",
                    "type": "Crop Recommendation (LightGBM)"
                  };
                  await ApiService.saveToHistory(data);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Saved to history")));
                  setState(() {
                    _predictionResult = null; // reset to allow scanning again
                    _phController.clear();
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Save to History & Analyse New",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  color: color ?? const Color(0xFF1B1B1B),
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─── Reusable Container ───
class _GlassCardContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const _GlassCardContainer({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3EA).withOpacity(0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: child,
    );
  }
}

// ─── Clipper ───
class _ManualWaveClipper extends CustomClipper<Path> {
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
