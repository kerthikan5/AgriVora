/// **PermissionPage**
/// Responsible for: Requesting mandatory local permissions (Location, Bluetooth, Camera).
/// Dependency: permission_handler.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/session_service.dart';

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _isLoaded = true);
    });
  }

  // ✅ Shared navigation logic — persists the permission grant
  void _onContinue() async {
    // Save the flag so we never show this screen again
    await SessionService.markPermissionsGranted();

    if (!mounted) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    final isGuest = args is Map && args['isGuest'] == true;

    if (isGuest) {
      Navigator.pushNamed(context, '/role', arguments: 'Guest');
    } else {
      Navigator.pushNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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

          // 🌿 Logo (top)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Image.asset(
                  'assets/images/logo_agrivora.png',
                  height: 170,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // 🟫 Glass permission card (slide up)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutQuart,
            bottom: _isLoaded ? 0 : -size.height,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: SoilWaveClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  height: size.height * 0.76,
                  width: double.infinity,
                  // ✅ frosted glass tint (matches login)
                  color: const Color(0xFFF2E8D5).withOpacity(0.78),
                  padding: EdgeInsets.fromLTRB(24, 72, 24, bottomPadding + 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Permissions\nRequired',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          color: Color(0xFF1B1B1B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'To help you grow better, AgriVora needs access to your location and sensors.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ✅ Static Column instead of ListView for perfect alignment
                      Expanded(
                        child: Column(
                          children: const [
                            PermissionTile(
                              icon: Icons.location_on_rounded,
                              title: 'Location Services',
                              subtitle: 'For local soil & weather data.',
                            ),
                            SizedBox(height: 10),
                            PermissionTile(
                              icon: Icons.camera_alt_rounded,
                              title: 'Camera Access',
                              subtitle: 'To scan soil texture and leaves.',
                            ),
                            SizedBox(height: 10),
                            PermissionTile(
                              icon: Icons.bluetooth_rounded,
                              title: 'Bluetooth & Wi-Fi',
                              subtitle: 'To sync with your ESP32 sensor.',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ✅ Allow All -> Next Step
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004D40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(34),
                            ),
                            elevation: 10,
                            shadowColor:
                                const Color(0xFF004D40).withOpacity(0.35),
                          ),
                          child: const Text(
                            'Allow All',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Center(
                        child: TextButton(
                          onPressed: _onContinue,
                          child: const Text(
                            'Maybe Later',
                            style: TextStyle(
                              color: Colors.black38,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🌊 Same smooth wave top
class SoilWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 60);
    path.quadraticBezierTo(size.width * 0.25, 10, size.width * 0.55, 55);
    path.quadraticBezierTo(size.width * 0.85, 95, size.width, 45);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ✅ Static Permission item with no animations and better resizing
class PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const PermissionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        // ✅ soft “field” tile look (not pure white)
        color: const Color(0xFFEAF3E6).withOpacity(0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ✅ round icon bubble like your permission page style
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF004D40),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
