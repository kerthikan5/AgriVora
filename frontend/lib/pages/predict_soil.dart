/// **PredictSoilPage**
/// Responsible for: Location-based soil prediction fetching.
/// Role: Grabs current GPS, fetches soil grids data via backend, and provides automated crop recommendations.
/// API Dependency: /location/summary, /recommend

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/ble_service.dart';

class PredictSoilPage extends StatefulWidget {
  const PredictSoilPage({super.key});

  @override
  State<PredictSoilPage> createState() => _PredictSoilPageState();
}

class _PredictSoilPageState extends State<PredictSoilPage> {
  // BLE state
  double? _livePh;
  PhReading? _lastReading;
  BleStatus _bleStatus = const BleStatus(
    message: 'Initializing BLE…',
    state: BleConnectionState.scanning,
  );

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    // Step 1: Initiate BLE hardware scan and attempt connection to paired ESP32 sensor
    BleService().startScanAndConnect();

    // Step 2: Register stream listeners for live pH values
    _subs.add(BleService().phStream.listen((ph) {
      if (mounted) setState(() => _livePh = ph);
    }));

    // Step 3: Register stream listeners for complete reading payloads (including voltage and temperature)
    _subs.add(BleService().rawStream.listen((r) {
      if (mounted) setState(() => _lastReading = r);
    }));

    // Step 4: Register stream listeners for connection status updates
    _subs.add(BleService().statusStream.listen((s) {
      if (mounted) setState(() => _bleStatus = s);
    }));
  }

  @override
  void dispose() {
    // Step 5: Clean up all stream subscriptions to avoid memory leaks
    for (final s in _subs) {
      s.cancel();
    }
    // Step 6: Disconnect from BLE to save battery and free the sensor
    BleService().disconnect();
    super.dispose();
  }

  Widget _buildPhCard() {
    final st = _bleStatus.state;
    final isConn = st == BleConnectionState.connected;
    final isStab = st == BleConnectionState.stabilizing;
    final isSim = st == BleConnectionState.simulating;

    Color phColor = const Color(0xFF2E7D32);
    String category = '';
    if (_livePh != null) {
      final ph = _livePh!;
      if (ph < 5.5) {
        phColor = const Color(0xFFD32F2F);
        category = 'Strongly Acidic';
      } else if (ph < 6.5) {
        phColor = const Color(0xFFF57C00);
        category = 'Acidic';
      } else if (ph < 7.5) {
        phColor = const Color(0xFF2E7D32);
        category = 'Neutral';
      } else if (ph < 8.5) {
        phColor = const Color(0xFF1565C0);
        category = 'Alkaline';
      } else {
        phColor = const Color(0xFF6A1B9A);
        category = 'Strongly Alkaline';
      }
    }

    String badgeLabel = 'Scanning…';
    Color badgeColor = Colors.grey;
    if (isConn) {
      badgeLabel = '● Live';
      badgeColor = const Color(0xFF2E7D32);
    }
    if (isStab) {
      badgeLabel = '⏳ Stabilizing';
      badgeColor = const Color(0xFFF57C00);
    }
    if (isSim) {
      badgeLabel = '🔵 Simulated';
      badgeColor = const Color(0xFF1565C0);
    }

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.science_rounded,
                      color: Color(0xFF2E7D32), size: 24),
                  const SizedBox(width: 8),
                  const Text('Live pH Reading',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B1B1B))),
                ]),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor.withOpacity(0.4)),
                  ),
                  child: Text(badgeLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeColor)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_livePh != null) ...[
              Text(
                _livePh!.toStringAsFixed(2),
                style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: phColor,
                    letterSpacing: -1),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: phColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(category,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: phColor)),
              ),
            ] else
              const SizedBox(
                height: 56,
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
              ),
            const SizedBox(height: 12),
            if (_lastReading != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_lastReading!.temperature != null) ...[
                    const Icon(Icons.thermostat_outlined,
                        size: 14, color: Colors.black45),
                    const SizedBox(width: 3),
                    Text('${_lastReading!.temperature!.toStringAsFixed(1)}°C',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                    const SizedBox(width: 12),
                  ],
                  if (_lastReading!.voltage != null) ...[
                    const Icon(Icons.electric_bolt_outlined,
                        size: 14, color: Colors.black45),
                    const SizedBox(width: 3),
                    Text('${_lastReading!.voltage!.toStringAsFixed(2)} V',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                    const SizedBox(width: 12),
                  ],
                  const Icon(Icons.access_time_rounded,
                      size: 14, color: Colors.black45),
                  const SizedBox(width: 3),
                  Text(_fmtTime(_lastReading!.timestamp),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              _bleStatus.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isConn ? const Color(0xFF2E7D32) : Colors.black45,
                fontStyle: isSim ? FontStyle.italic : FontStyle.normal,
                height: 1.35,
              ),
            ),
            if (_livePh != null && !isSim && _livePh! < 5.5)
              _TipBanner(
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFD32F2F),
                text:
                    'pH too low – consider applying lime to improve soil health.',
              ),
            if (_livePh != null && !isSim && _livePh! > 7.5)
              _TipBanner(
                icon: Icons.info_outline_rounded,
                color: const Color(0xFF1565C0),
                text: 'pH too high – consider adding sulfur or compost.',
              ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }

  @override
  Widget build(BuildContext context) {
    // Step 7: Build the full view starting with screen size calculation
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5),
      body: Stack(
        children: [
          // Step 8: Apply dynamic background image cover
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_fields.png',
              fit: BoxFit.cover,
            ),
          ),
          
          // Step 9: Render curved frosted glass bottom sheet 
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _PredictWaveClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  height: size.height * 0.72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2E8D5).withOpacity(0.74),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 18, top: 12),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withOpacity(0.6),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF2E7D32)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      Text(
                        "Predict Soil",
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B1B1B),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Get live pH reading using our BLE sensor",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: 230,
                        child: Divider(
                          thickness: 2,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                    child: Column(
                      children: [
                        _buildPhCard(),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Reconnecting to ESP32 sensor...'),
                                  backgroundColor: Color(0xFF2E7D32),
                                ),
                              );
                              BleService().startScanAndConnect();
                            },
                            icon: const Icon(Icons.bluetooth_connected,
                                color: Colors.white),
                            label: const Text(
                              "Reconnect ESP32 Device",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              elevation: 10,
                              shadowColor:
                                  const Color(0xFF1565C0).withOpacity(0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(34),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/crop-recom',
                                  arguments: {'ph': _livePh});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              elevation: 10,
                              shadowColor:
                                  const Color(0xFF2E7D32).withOpacity(0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(34),
                              ),
                            ),
                            child: const Text(
                              "Proceed to Recommendation",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/manual-soil',
                                arguments: {'ph': _livePh});
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2E7D32),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          child: const Text(
                            "Continue with manual input soil pH\nto predict crops",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 120);

    path.quadraticBezierTo(size.width * 0.25, 45, size.width * 0.55, 112);
    path.quadraticBezierTo(size.width * 0.86, 175, size.width, 100);

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3EA).withOpacity(0.55),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
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

class _TipBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _TipBanner(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}
