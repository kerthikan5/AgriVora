/// **ProfilePage**
/// Responsible for: Rendering the user profile and account details.
/// Role: Displays logged-in user summary and allows navigation to account settings or logout.
/// Dependency: SessionService for current user state.

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _profileImagePath;
  bool get isGuest => ApiService.userId == null;

  // Farm Insights data
  bool _isLoadingHistory = true;
  int _totalPredictions = 0;
  String _topCrop = "None";
  final String _avgHealth = "Good";
  String _lastAnalysis = "N/A";

  @override
  void initState() {
    super.initState();
    _loadProfilePic();
    if (!isGuest) {
      _fetchHistoryStats();
      ApiService.historyRefreshTrigger.addListener(_fetchHistoryStats);
    } else {
      _isLoadingHistory = false;
    }
  }

  @override
  void dispose() {
    ApiService.historyRefreshTrigger.removeListener(_fetchHistoryStats);
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (!isGuest) {
      await _fetchHistoryStats();
    }
    await _loadProfilePic();
    if (mounted) setState(() {});
  }

  Future<void> _loadProfilePic() async {
    final path = await SessionService.getProfilePic();
    if (path != null && mounted) {
      setState(() {
        _profileImagePath = path;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final path = pickedFile.path;
      await SessionService.saveProfilePic(path);
      if (mounted) {
        setState(() {
          _profileImagePath = path;
        });
      }
    }
  }

  Future<void> _fetchHistoryStats() async {
    try {
      final res = await ApiService.getUserHistory();
      if (mounted && res.isNotEmpty) {
        int total = res.length;
        Map<String, int> cropCounts = {};
        for (var item in res) {
          if (item['results'] != null &&
              item['results'] is List &&
              (item['results'] as List).isNotEmpty) {
            String c = (item['results'] as List).first.toString();
            cropCounts[c] = (cropCounts[c] ?? 0) + 1;
          } else if (item['crop'] != null) {
            String c = item['crop'].toString();
            cropCounts[c] = (cropCounts[c] ?? 0) + 1;
          }
        }
        String topCrop = "None";
        if (cropCounts.isNotEmpty) {
          topCrop = cropCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
        }

        String lastSync = "N/A";
        final firstItem = res.first as Map<String, dynamic>;
        if (firstItem.containsKey("createdAt")) {
          try {
            if (firstItem['createdAt'] is String) {
              DateTime dt = DateTime.parse(firstItem['createdAt']);
              lastSync = "${dt.day}/${dt.month}/${dt.year}";
            } else if (firstItem['createdAt'] is Map &&
                firstItem['createdAt']['_seconds'] != null) {
              DateTime dt = DateTime.fromMillisecondsSinceEpoch(
                  firstItem['createdAt']['_seconds'] * 1000);
              lastSync = "${dt.day}/${dt.month}/${dt.year}";
            }
          } catch (_) {}
        }

        setState(() {
          _totalPredictions = total;
          _topCrop = topCrop;
          _lastAnalysis = lastSync;
          _isLoadingHistory = false;
        });
      } else {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
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
          // 🌾 Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_fields.png',
              fit: BoxFit.cover,
            ),
          ),

          // ✅ Top Header
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
                      "Profile",
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
                      "Manage Your Farming Account",
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
                  child: const Icon(Icons.settings_outlined,
                      color: Colors.white, size: 28),
                ),
              ],
            ),
          ),

          // ✅ Large Wavy Glass Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _ProfileWaveClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  height: size.height * 0.88,
                  padding: EdgeInsets.fromLTRB(16, 110, 16, bottomPad + 70),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2E8D5).withOpacity(0.68),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: RefreshIndicator(
                    onRefresh: _refreshData,
                    color: const Color(0xFF2E7D32),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        children: [
                          _buildProfileOverviewCard(),
                          const SizedBox(height: 14),
                          _buildPersonalInfoCard(),
                          const SizedBox(height: 14),
                          _buildFarmInsightsSummary(),
                          const SizedBox(height: 14),
                          _buildSettingsCard(),
                          const SizedBox(height: 24),
                          _buildActionSection(),
                        ],
                      ),
                    ),
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

  // 1. Profile Overview Card
  Widget _buildProfileOverviewCard() {
    return _buildGlassElevatedCard(
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: isGuest ? null : _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: isGuest
                            ? Colors.grey.shade400
                            : const Color(0xFF2E7D32),
                        backgroundImage: (!isGuest && _profileImagePath != null)
                            ? FileImage(File(_profileImagePath!))
                            : null,
                        child: (isGuest || _profileImagePath == null)
                            ? Icon(
                                isGuest
                                    ? Icons.no_accounts_rounded
                                    : Icons.person_rounded,
                                size: 40,
                                color: Colors.white)
                            : null,
                      ),
                    ),
                    if (!isGuest)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4)
                          ],
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Color(0xFF2E7D32), size: 14),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGuest
                          ? "Guest User"
                          : (ApiService.userName ?? "AgriVora Farmer"),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B1B1B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGuest ? "Guest Access" : "Registered Farmer",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isGuest
                              ? Colors.grey.shade600
                              : const Color(0xFF2E7D32)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(Icons.location_on_rounded,
                            size: 14, color: Colors.black54),
                        SizedBox(width: 4),
                        Text("Colombo, Sri Lanka",
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
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
                child: const Text("Active",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Personal Information Card
  Widget _buildPersonalInfoCard() {
    return _buildGlassElevatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Personal Details",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1B))),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.email_outlined, "Email",
              isGuest ? "Not available" : (ApiService.userEmail ?? "-")),
          _buildInfoRow(Icons.phone_outlined, "Phone",
              isGuest ? "Not available" : (ApiService.userPhone ?? "-"),
              noDivider: true),
        ],
      ),
    );
  }

  // 3. Farm Insights Summary (Mini Dashboard)
  Widget _buildFarmInsightsSummary() {
    if (isGuest) return const SizedBox.shrink();

    return _buildGlassElevatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Farm Insights Summary",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1B))),
          const SizedBox(height: 14),
          if (_isLoadingHistory)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Color(0xFF2E7D32))))
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _buildMiniStatCard(Icons.analytics,
                            "Total Predicts", _totalPredictions.toString())),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildMiniStatCard(
                            Icons.eco, "Top Crop", _topCrop)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _buildMiniStatCard(
                            Icons.healing, "Avg Health", _avgHealth)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildMiniStatCard(
                            Icons.event, "Last Analysis", _lastAnalysis)),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2E7D32), size: 18),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // 4. Settings & Controls
  Widget _buildSettingsCard() {
    return _buildGlassElevatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Settings & Controls",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1B))),
          const SizedBox(height: 12),
          _buildActionRow(Icons.person_outline, "Account Settings", () {
            if (!isGuest) {
              Navigator.pushNamed(context, '/account-settings').then((_) {
                if (mounted) setState(() {});
              });
            }
          }),
          _buildActionRow(Icons.lock_outline, "Privacy Policy", () async {
            final url = Uri.parse(
                'https://github.com/AgriVora-Team/AgriVora/blob/main/docs/AgriVora_Privacy_Policy.md');
            launchUrl(url, mode: LaunchMode.externalApplication);
          }),
          _buildActionRow(Icons.description_outlined, "Terms & Conditions",
              () async {
            final url = Uri.parse(
                'https://github.com/AgriVora-Team/AgriVora/blob/main/docs/AgriVora_Terms_and_Conditions.pdf');
            launchUrl(url, mode: LaunchMode.externalApplication);
          }, noDivider: true),
        ],
      ),
    );
  }

  // 5. Action Section
  Widget _buildActionSection() {
    if (isGuest) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
                context, '/welcome', (route) => false);
          },
          icon: const Icon(Icons.login, color: Colors.white, size: 20),
          label: const Text("Sign In / Create Account",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            elevation: 4,
            shadowColor: const Color(0xFF2E7D32).withOpacity(0.4),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            await ApiService.logout();
            if (!mounted) return;
            Navigator.pushNamedAndRemoveUntil(
                context, '/welcome', (route) => false);
          },
          icon: const Icon(Icons.logout_rounded,
              color: Colors.redAccent, size: 20),
          label: const Text("Log Out",
              style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.8),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: Colors.redAccent, width: 1.5)),
            elevation: 0,
          ),
        ),
      );
    }
  }

  // ─── Shared UI Helpers ───

  Widget _buildGlassElevatedCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3EA).withOpacity(0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool noDivider = false}) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600)),
            ),
            Expanded(
              flex: 3,
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1B1B1B),
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        if (!noDivider)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.black12, height: 1)),
      ],
    );
  }

  Widget _buildActionRow(IconData icon, String label, VoidCallback onTap,
      {bool noDivider = false}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          highlightColor: Colors.transparent,
          splashColor: const Color(0xFF2E7D32).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B1B1B)))),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: Colors.black45),
              ],
            ),
          ),
        ),
        if (!noDivider)
          const Padding(
              padding: EdgeInsets.only(left: 44),
              child: Divider(color: Colors.black12, height: 1)),
      ],
    );
  }
}

class _ProfileWaveClipper extends CustomClipper<Path> {
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
