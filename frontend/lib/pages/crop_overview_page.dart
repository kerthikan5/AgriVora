/// **CropOverviewPage**
/// Responsible for: Showing detailed info about a specific recommended crop.
/// Role: A static/dynamic view providing crop parameters like name, scientific name, and images.
/// Navigational: Accessed from CropRecomPage.

import 'dart:ui';
import 'package:flutter/material.dart';

class CropOverviewPage extends StatelessWidget {
  final String name;
  final String scientific;
  final String image;

  const CropOverviewPage({
    super.key,
    required this.name,
    required this.scientific,
    required this.image,
  });

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
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 32,
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
                        "AI Recommended Based on Your Soil Data",
                        style: TextStyle(
                          fontSize: 12,
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
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2E7D32).withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            "85% Suitable",
                            style: TextStyle(
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
                  height: 65,
                  width: 65,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Icon(Icons.spa_rounded,
                      color: Colors.white, size: 32),
                ),
              ],
            ),
          ),

          // Wavy Glass Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _OverviewWaveClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  height: size.height * 0.85,
                  padding: EdgeInsets.fromLTRB(16, 80, 16, bottomPad + 70),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2E8D5).withValues(alpha: 0.75),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        _buildSummaryCard(),
                        const SizedBox(height: 16),
                        _buildSoilCompatibility(),
                        const SizedBox(height: 16),
                        _buildClimateSuitability(),
                        const SizedBox(height: 16),
                        _buildFarmingTips(),
                        const SizedBox(height: 24),
                        _buildActionButtons(context),
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

  // 1. Crop Summary Card
  Widget _buildSummaryCard() {
    return _GlassCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              const Text("Crop Overview",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1B1B))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
              "$name ($scientific) is highly suitable for your chosen field. It requires a balanced nutrient supply and can thrive well in the upcoming tropical growing season.",
              style: const TextStyle(
                  fontSize: 13, color: Colors.black87, height: 1.4)),
          const SizedBox(height: 16),
          _buildParamRow(Icons.science_outlined, "Ideal pH Range", "6.0 - 7.5"),
          _buildParamRow(
              Icons.thermostat_outlined, "Temperature", "20°C - 30°C"),
          _buildParamRow(
              Icons.water_drop_outlined, "Water Needs", "Moderate (400mm)"),
          _buildParamRow(
              Icons.date_range_rounded, "Growing Season", "Maha / Yala"),
        ],
      ),
    );
  }

  // 2. Soil Compatibility Section
  Widget _buildSoilCompatibility() {
    return _GlassCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.landscape_rounded, color: Color(0xFF795548)),
              const SizedBox(width: 8),
              const Text("Soil Compatibility",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1B1B))),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text("Good",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32))),
              )
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressBar("Your Soil pH (6.5) vs Ideal", 0.8),
          const SizedBox(height: 12),
          _buildProgressBar("Nitrogen Match (N)", 0.65),
        ],
      ),
    );
  }

  // 3. Climate Suitability
  Widget _buildClimateSuitability() {
    return _GlassCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_outlined, color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              const Text("Climate Suitability",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1B1B))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMiniBox(
                  Icons.thermostat, "Temp Match", "Optimal", Colors.orange),
              const SizedBox(width: 12),
              _buildMiniBox(
                  Icons.water_drop, "Rainfall", "Adequate", Colors.blue),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.wb_twilight_rounded,
                    size: 20, color: Color(0xFF1565C0)),
                const SizedBox(width: 10),
                Expanded(
                  child: const Text(
                      "Current weather patterns indicate a highly favorable environment for early germination.",
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 4. Farming Tips
  Widget _buildFarmingTips() {
    return _GlassCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  color: Color(0xFFF57C00)),
              const SizedBox(width: 8),
              const Text("Farming Advice",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1B1B))),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipRow(
              "Fertilizer", "Use NPK 15-15-15 during vegetative stage"),
          _buildTipRow(
              "Irrigation", "Drip irrigation recommended for water efficiency"),
          _buildTipRow(
              "Pest Risk", "Moderate. Watch for early aphid outbreaks"),
          _buildTipRow(
              "Harvest Duration", "Estimated 80-100 days from planting"),
        ],
      ),
    );
  }

  // 5. Action Section
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // Usually handled internally via prediction save, but mock UI action here
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Crop details saved to History!")));
            },
            icon: const Icon(Icons.bookmark_added_rounded, color: Colors.white),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            label: const Text("Save to History",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Color(0xFF2E7D32), size: 18),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                label: const Text("Alternative Crops",
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/ai_chat');
                },
                icon: const Icon(Icons.smart_toy_rounded,
                    color: Colors.white, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                label: const Text("Ask AI About Crop",
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        )
      ],
    );
  }

  // ─── Utility Widgets ───

  Widget _buildParamRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2E7D32), size: 18),
          ),
          const SizedBox(width: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1B))),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            Text("${(progress * 100).toInt()}% Match",
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2E7D32))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.black12,
            color: const Color(0xFF2E7D32),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniBox(IconData icon, String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B1B1B))),
          ],
        ),
      ),
    );
  }

  Widget _buildTipRow(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFF57C00),
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
                        fontSize: 12,
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

class _GlassCardContainer extends StatelessWidget {
  final Widget child;
  const _GlassCardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }
}

class _OverviewWaveClipper extends CustomClipper<Path> {
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
