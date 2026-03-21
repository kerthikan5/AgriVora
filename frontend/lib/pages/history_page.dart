/// **HistoryPage**
/// Responsible for: Showing the user's past soil analyses.
/// Role: Fetches and lists historical scan records from the database via ApiService.
/// API Dependency: /history/{userId}

import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _isLoading = true;
  String? _errorMsg;
  List<dynamic> _historyData = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    // Listen for automatic history updates from API service
    ApiService.historyRefreshTrigger.addListener(_fetchHistorySilently);
  }

  @override
  void dispose() {
    ApiService.historyRefreshTrigger.removeListener(_fetchHistorySilently);
    super.dispose();
  }

  /// Silently fetch history in the background without showing full loading screen
  Future<void> _fetchHistorySilently() async {
    try {
      // Step 1: Attempt to fetch user history from ApiService
      final res = await ApiService.getUserHistory();
      // Step 2: If mounted, update the state with fetched history and clear error message
      if (mounted) {
        setState(() {
          _historyData = res;
          _errorMsg = null;
        });
      }
    } catch (_) {
      // Step 3: Catch and ignore any background errors
    }
  }

  Future<void> _fetchHistory() async {
    // Step 1: Set loading state to true and clear any previous error message
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      // Step 2: Try fetching history records via ApiService
      final res = await ApiService.getUserHistory();
      // Step 3: If successful and widget is still mounted, update state with data and stop loading indicator
      if (mounted) {
        setState(() {
          _historyData = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Step 4: If an error is caught and widget is mounted, format error message and stop loading indicator
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
    // Step 1: Initialize screen dimensions and safe area paddings
    final size = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    // Step 2: Build main Scaffold and Stack structure for layered UI
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5),
      body: Stack(
        children: [
          // Step 3: Add full-screen background image
          // 🌾 Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_fields.png',
              fit: BoxFit.cover,
            ),
          ),

          // Step 4: Add floating top header containing title and icon
          // ✅ Top Header (Floating over the image)
          Positioned(
            top: MediaQuery.of(context).padding.top + 55,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Prediction History",
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
                      "Your Soil & Crop Analysis Records",
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child:
                      const Icon(Icons.history, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),

          // Step 5: Create a frosted glass container with a wavy cutout for main content
          // ✅ Large Wavy Glass Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _HistoryWaveClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  height: size.height * 0.88,
                  padding: EdgeInsets.fromLTRB(16, 120, 16, bottomPad + 70),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2E8D5).withOpacity(0.68),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step 6: Display summary analytics dashboard if data is available and no errors occurred
                      // Summary Analytics Dashboard
                      if (!_isLoading &&
                          _historyData.isNotEmpty &&
                          _errorMsg == null)
                        _buildSummaryDashboard(),
                      if (!_isLoading &&
                          _historyData.isNotEmpty &&
                          _errorMsg == null)
                        const SizedBox(height: 16),

                      // Step 7: Render the main body content (loading, error, empty, or list of cards)
                      Expanded(
                        child: _buildBody(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 🧭 The Floating Navigation Bar

        ],
      ),
    );
  }

  Widget _buildSummaryDashboard() {
    String topCrop = "None";
    if (_historyData.isNotEmpty) {
      Map<String, int> cropCounts = {};
      for (var item in _historyData) {
        // Shape 1: LightGBM /crop/recommend saves recommended_crop directly
        if (item['recommended_crop'] != null) {
          String c = item['recommended_crop'].toString();
          cropCounts[c] = (cropCounts[c] ?? 0) + 1;
        }
        // Shape 2: /recommend saves results as a list of {name, score, ...}
        else if (item['results'] != null && item['results'] is List) {
          final results = item['results'] as List;
          if (results.isNotEmpty) {
            final first = results.first;
            final c = (first is Map
                    ? (first['name'] ?? first['crop'] ?? first.toString())
                    : first)
                .toString();
            if (c.isNotEmpty && c != 'null')
              cropCounts[c] = (cropCounts[c] ?? 0) + 1;
          }
        }
        // Shape 3: has 'crop' key directly
        else if (item['crop'] != null) {
          String c = item['crop'].toString();
          cropCounts[c] = (cropCounts[c] ?? 0) + 1;
        }
      }
      if (cropCounts.isNotEmpty) {
        topCrop =
            cropCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }
    }

    String lastSync = "N/A";
    if (_historyData.isNotEmpty) {
      final firstItem = _historyData.first as Map<String, dynamic>;
      if (firstItem.containsKey("createdAt")) {
        try {
          if (firstItem['createdAt'] is String) {
            DateTime dt = DateTime.parse(firstItem['createdAt']).toLocal();
            lastSync = "${dt.day}/${dt.month}/${dt.year}";
          } else if (firstItem['createdAt'] is Map &&
              firstItem['createdAt']['_seconds'] != null) {
            DateTime dt = DateTime.fromMillisecondsSinceEpoch(
                    firstItem['createdAt']['_seconds'] * 1000)
                .toLocal();
            lastSync = "${dt.day}/${dt.month}/${dt.year}";
          }
        } catch (_) {}
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Analytics Overview",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1B)),
            ),
            InkWell(
              onTap: _fetchHistory,
              child:
                  const Icon(Icons.refresh, color: Color(0xFF2E7D32), size: 20),
            )
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _buildMiniStatCard(Icons.analytics, "Total Predicts",
                    _historyData.length.toString())),
            const SizedBox(width: 10),
            Expanded(child: _buildMiniStatCard(Icons.eco, "Top Crop", topCrop)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _buildMiniStatCard(Icons.healing, "Avg Health", "Good")),
            const SizedBox(width: 10),
            Expanded(
                child:
                    _buildMiniStatCard(Icons.event, "Last Analysis", lastSync)),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStatCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3EA).withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2E7D32), size: 20),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF2E7D32)),
            SizedBox(height: 16),
            Text("Loading history...",
                style: TextStyle(
                    color: Colors.black54, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 50),
              const SizedBox(height: 16),
              const Text("Failed to Load",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 8),
              Text(_errorMsg!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchHistory,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label:
                    const Text("Retry", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              )
            ],
          ),
        ),
      );
    }

    if (_historyData.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.analytics_outlined,
                  size: 50, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 16),
            const Text(
              "No Analysis Records Yet",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1B)),
            ),
            const SizedBox(height: 8),
            const Text(
              "Start a soil analysis to generate\ncrop recommendations.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Navigate to manual soil entry or predict soil
                Navigator.pushNamed(context, '/manual-soil');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text("Start Analysis",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: const Color(0xFF2E7D32),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 20),
        itemCount: _historyData.length,
        itemBuilder: (context, index) {
          final item = _historyData[index] as Map<String, dynamic>;
          return _buildHistoryCard(context, item);
        },
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> item) {
    // ── Detect card type ──────────────────────────────────────────
    final bool isTexture = item.containsKey('texture') ||
        (item['scan_type']?.toString() == 'soil_scan');
    final bool isCropLGBM = item.containsKey('recommended_crop');

    // ── Top Crop: handle all save shapes ─────────────────────────
    String topCrop = 'N/A';
    if (!isTexture) {
      if (isCropLGBM && item['recommended_crop'] != null) {
        topCrop = item['recommended_crop'].toString();
      } else if (item['results'] != null && item['results'] is List) {
        final results = item['results'] as List;
        if (results.isNotEmpty) {
          final first = results.first;
          topCrop = (first is Map
              ? (first['name'] ?? first['crop'] ?? 'N/A').toString()
              : first.toString());
        }
      } else if (item['crop'] != null) {
        topCrop = item['crop'].toString();
      }
    }

    // ── pH: may be at root or inside soilSummary ─────────────────
    String phStr = 'N/A';
    if (item['ph'] != null) {
      phStr = item['ph'].toString();
    } else if (item['soilSummary'] is Map &&
        item['soilSummary']['ph'] != null) {
      phStr = item['soilSummary']['ph'].toString();
    }

    // ── Soil type: detect from multiple fields ────────────────────
    String soilTypeStr = 'Unknown';
    if (item['soil_type'] != null) {
      soilTypeStr = item['soil_type'].toString();
    } else if (item['texture'] != null) {
      soilTypeStr = item['texture'].toString();
    } else if (item['soilSummary'] is Map) {
      final ss = item['soilSummary'] as Map;
      // Try to guess from sand/clay content
      final sand = ss['sand'];
      final clay = ss['clay'];
      if (sand != null && clay != null) {
        soilTypeStr = 'Sand:$sand Clay:$clay';
      }
    }

    // ── Confidence ────────────────────────────────────────────────
    String confStr = '—';
    if (item['confidence'] != null) {
      final conf = item['confidence'];
      confStr = conf is double
          ? '${(conf * 100).toStringAsFixed(0)}%'
          : conf.toString();
    }

    // ── Date formatting ───────────────────────────────────────────
    String dateStr = 'Unknown Date';
    String timeStr = '';
    try {
      final raw = item['createdAt'];
      DateTime? dt;
      if (raw is String && raw.isNotEmpty) {
        dt = DateTime.parse(raw).toLocal();
      } else if (raw is Map && raw['_seconds'] != null) {
        dt =
            DateTime.fromMillisecondsSinceEpoch((raw['_seconds'] as int) * 1000)
                .toLocal();
      }
      if (dt != null) {
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
        timeStr = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    // ── Card visuals ──────────────────────────────────────────────
    final IconData cardIcon =
        isTexture ? Icons.science_rounded : Icons.eco_rounded;
    final Color cardAccent =
        isTexture ? const Color(0xFF795548) : const Color(0xFF2E7D32);
    final String cardType = isTexture
        ? 'Soil Analysis'
        : isCropLGBM
            ? 'Crop Recommendation (AI)'
            : 'Crop Recommendation';

    return InkWell(
      onTap: () {
        // Normally open detail, skip for now or navigate to crop overview
      },
      onLongPress: () {
        // Shows delete prompt (implement later)
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3EA).withOpacity(0.65),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: cardAccent.withOpacity(0.12),
                      shape: BoxShape.circle),
                  child: Icon(cardIcon, color: cardAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cardType,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: cardAccent)),
                      Text("$dateStr • $timeStr",
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text("Good",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 10),
            if (isTexture) ...[
              _InfoRow(
                  'Soil Texture', item['texture']?.toString() ?? soilTypeStr),
              _InfoRow('Confidence', confStr),
              _InfoRow('Water Capacity',
                  item['water_capacity']?.toString() ?? 'N/A'),
            ] else ...[
              Row(
                children: [
                  Expanded(child: _InfoRow('Top Crop', topCrop)),
                  Expanded(child: _InfoRow('Confidence', confStr)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _InfoRow('Soil pH', phStr)),
                  Expanded(child: _InfoRow('Soil Type', soilTypeStr)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _InfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1B1B))),
        ],
      ),
    );
  }
}

class _HistoryWaveClipper extends CustomClipper<Path> {
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
