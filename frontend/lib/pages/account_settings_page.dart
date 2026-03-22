/// **AccountSettingsPage**
/// Responsible for: Profile editing and password updates.
/// API Dependency: PUT /api/users/profile, /api/users/change-password

import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  bool get isGuest => ApiService.userId == null;
  String? _profileImagePath;

  bool _isLoadingProfile = false;
  bool _isLoadingPassword = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfilePic();
    _nameController.text = ApiService.userName ?? '';
    _phoneController.text = ApiService.userPhone ?? '';
    _refreshProfileSilently();
  }

  /// Silently re-fetches profile from backend so the UI shows the latest name/phone
  Future<void> _refreshProfileSilently() async {
    if (ApiService.userId == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/users/profile/${ApiService.userId}'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body) as Map<String, dynamic>;
        if (d['success'] == true && d['data'] != null) {
          final data = d['data'] as Map<String, dynamic>;
          ApiService.userName = data['full_name']?.toString();
          ApiService.userEmail = data['email']?.toString();
          ApiService.userPhone = data['phone']?.toString();
          if (mounted) {
            setState(() {
              _nameController.text = ApiService.userName ?? '';
              _phoneController.text = ApiService.userPhone ?? '';
            });
          }
        }
      }
    } catch (_) {} // silent — non-critical
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

  Future<void> _showEditProfileDialog() async {
    _nameController.text = ApiService.userName ?? '';
    _phoneController.text = ApiService.userPhone ?? '';

    await showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF2E8D5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text("Edit Profile",
                  style: TextStyle(fontWeight: FontWeight.w900)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: const Icon(Icons.person_outline,
                          color: Color(0xFF2E7D32)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFF2E7D32), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "Phone Number",
                      prefixIcon: const Icon(Icons.phone_outlined,
                          color: Color(0xFF2E7D32)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFF2E7D32), width: 1.5)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel",
                      style: TextStyle(color: Colors.black54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoadingProfile
                      ? null
                      : () async {
                          final name = _nameController.text.trim();
                          final phone = _phoneController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Name cannot be empty')));
                            return;
                          }

                          setDialogState(() => _isLoadingProfile = true);
                          try {
                            await ApiService.updateProfile(
                                fullName: name.isNotEmpty ? name : null,
                                phone: phone.isNotEmpty ? phone : null);
                            // Close the dialog first
                            if (ctx.mounted) Navigator.pop(ctx);
                            // Then rebuild the page to show updated name/phone
                            if (mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text('Profile updated successfully!'),
                                backgroundColor: Color(0xFF2E7D32),
                                duration: Duration(seconds: 2),
                              ));
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(
                                    e.toString().replaceAll('Exception: ', '')),
                                backgroundColor: Colors.redAccent,
                              ));
                            }
                          } finally {
                            if (mounted)
                              setDialogState(() => _isLoadingProfile = false);
                          }
                        },
                  child: _isLoadingProfile
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("Save",
                          style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          });
        });
  }

  Future<void> _showChangePasswordDialog() async {
    _oldPasswordController.clear();
    _newPasswordController.clear();

    await showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF2E8D5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text("Change Password",
                  style: TextStyle(fontWeight: FontWeight.w900)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _oldPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Current Password",
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: Color(0xFF2E7D32)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFF2E7D32), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "New Password",
                      prefixIcon: const Icon(Icons.lock_reset_outlined,
                          color: Color(0xFF2E7D32)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFF2E7D32), width: 1.5)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel",
                      style: TextStyle(color: Colors.black54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoadingPassword
                      ? null
                      : () async {
                          final oldPw = _oldPasswordController.text.trim();
                          final newPw = _newPasswordController.text.trim();
                          if (oldPw.isEmpty || newPw.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Please fill in both fields')));
                            return;
                          }
                          if (newPw.length < 8) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'New password must be at least 8 characters')));
                            return;
                          }

                          setDialogState(() => _isLoadingPassword = true);
                          // Capture ScaffoldMessenger before async gap
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await ApiService.changePassword(
                                oldPassword: oldPw, newPassword: newPw);
                            // Close first, then show snackbar
                            if (ctx.mounted) Navigator.pop(ctx);
                            messenger.showSnackBar(const SnackBar(
                              content: Text('Password changed successfully!'),
                              backgroundColor: Color(0xFF2E7D32),
                              duration: Duration(seconds: 2),
                            ));
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(
                                content: Text(
                                    e.toString().replaceAll('Exception: ', '')),
                                backgroundColor: Colors.redAccent));
                          } finally {
                            if (mounted)
                              setDialogState(() => _isLoadingPassword = false);
                          }
                        },
                  child: _isLoadingPassword
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("Update",
                          style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          });
        });
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF2E8D5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Log Out",
            style: TextStyle(fontWeight: FontWeight.w900)),
        content:
            const Text("Are you sure you want to log out of your account?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/welcome', (route) => false);
              }
            },
            child: const Text("Logout",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5),
      body: Stack(
        children: [
          // 🌾 Background Fields Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_fields.png',
              fit: BoxFit.cover,
            ),
          ),

          // ✅ Top Header (Floating over the image)
          Positioned(
            top: MediaQuery.of(context).padding.top + 55,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.only(top: 4, right: 12),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 24),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Account Settings",
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
                        SizedBox(height: 4),
                        Text(
                          "Manage Your Profile & Preferences",
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
                      ],
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
                  child: const Icon(Icons.settings_suggest_rounded,
                      color: Colors.white, size: 26),
                ),
              ],
            ),
          ),

          // ✅ Large Wavy Glass Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _SettingsWaveClipper(),
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
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        _buildProfileOverviewCard(),
                        const SizedBox(height: 16),
                        if (!isGuest) _buildAccountSectionCard(),
                        if (!isGuest) const SizedBox(height: 16),
                        _buildSecurityCard(),
                        const SizedBox(height: 24),
                        _buildLogoutSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 🧭 Optional: Keep standard nav? Usually settings doesn't need floating nav,
          // but we follow "maintain bottom navigation consistency".
        ],
      ),
    );
  }

  // ─── 1. Profile Overview Card ───
  Widget _buildProfileOverviewCard() {
    return _GlassCardContainer(
      child: Row(
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
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: isGuest
                        ? Colors.grey.shade400
                        : const Color(0xFF2E7D32),
                    backgroundImage: _profileImagePath != null
                        ? FileImage(File(_profileImagePath!))
                        : null,
                    child: _profileImagePath == null
                        ? Icon(
                            isGuest
                                ? Icons.no_accounts_rounded
                                : Icons.person_rounded,
                            size: 38,
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
                            color: Colors.black.withOpacity(0.1), blurRadius: 4)
                      ],
                    ),
                    child: const Icon(Icons.edit_rounded,
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
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1B1B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isGuest
                      ? "Not available"
                      : (ApiService.userEmail ?? "No email linked"),
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Icon(Icons.location_on_rounded,
                        size: 12, color: Colors.black54),
                    SizedBox(width: 4),
                    Text("Colombo, Sri Lanka",
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          if (!isGuest)
            ElevatedButton(
              onPressed: _showEditProfileDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text("Edit Profile",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // ─── 2. Account Section ───
  Widget _buildAccountSectionCard() {
    return _GlassCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Account"),
          _buildActionRow(Icons.lock_reset_rounded, "Change Password",
              _showChangePasswordDialog),
          _buildActionRow(Icons.email_outlined, "Update Email", () {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Feature coming soon")));
          }, isLast: true),
        ],
      ),
    );
  }

  // ─── 5. Security & Privacy ───
  Widget _buildSecurityCard() {
    return _GlassCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Security & Privacy"),
          _buildActionRow(
              Icons.admin_panel_settings_outlined, "App Permissions", () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Location: Granted | Camera: Granted")));
          }),
          _buildActionRow(Icons.privacy_tip_outlined, "Privacy Policy",
              () async {
            final url = Uri.parse(
                'https://github.com/AgriVora-Team/AgriVora/blob/main/docs/AgriVora_Privacy_Policy.md');
            launchUrl(url, mode: LaunchMode.externalApplication);
          }),
          _buildActionRow(Icons.description_outlined, "Terms & Conditions",
              () async {
            final url = Uri.parse(
                'https://github.com/AgriVora-Team/AgriVora/blob/main/docs/AgriVora_Terms_and_Conditions.pdf');
            launchUrl(url, mode: LaunchMode.externalApplication);
          }, isLast: true),
        ],
      ),
    );
  }

  // ─── 6. Logout Section ───
  Widget _buildLogoutSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: OutlinedButton.icon(
        onPressed: _confirmLogout,
        icon:
            const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
        label: const Text("Logout",
            style: TextStyle(
                color: Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.redAccent, width: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: Colors.redAccent.withOpacity(0.05),
        ),
      ),
    );
  }

  // ─── Shared UI Helpers ───
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1B1B1B)),
      ),
    );
  }

  Widget _buildActionRow(IconData icon, String label, VoidCallback onTap,
      {bool isLast = false}) {
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
        if (!isLast)
          const Padding(
              padding: EdgeInsets.only(left: 44),
              child: Divider(color: Colors.black12, height: 1)),
      ],
    );
  }

  Widget _buildSwitchRow(
      IconData icon, String label, bool value, ValueChanged<bool> onChanged,
      {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
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
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF2E7D32),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.grey.shade400,
              ),
            ],
          ),
        ),
        if (!isLast)
          const Padding(
              padding: EdgeInsets.only(left: 44),
              child: Divider(color: Colors.black12, height: 1)),
      ],
    );
  }
}

// ─── Custom Global Card Container for Sections ───────────────────────────────
class _GlassCardContainer extends StatelessWidget {
  final Widget child;

  const _GlassCardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
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
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: child,
    );
  }
}

// ─── Shared Clipper ──────────────────────────────────────────────────────────
class _SettingsWaveClipper extends CustomClipper<Path> {
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
