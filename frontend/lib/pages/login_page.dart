/// **LoginPage**
/// Responsible for: User authentication (login).
/// Role: Captures email/phone and password, calls ApiService.login(), uses SessionService to save session state.
/// API Dependency: /api/auth/login

import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _isLoaded = true);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ✅ Log in -> Role select page
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all fields')),
      );
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.login(email, password);
      if (mounted) {
        // ✅ Persist the session so next cold-start skips onboarding
        await SessionService.saveSession(
          userId: ApiService.userId ?? '',
          userName: ApiService.userName ?? '',
          userEmail: ApiService.userEmail ?? '',
          userPhone: ApiService.userPhone ?? '',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Login successful')),
        );
        final fullName = response['full_name']?.toString() ?? 'User';
        Navigator.pushReplacementNamed(context, '/role', arguments: fullName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_fields.png',
              fit: BoxFit.cover,
            ),
          ),
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
          AnimatedPositioned(
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutQuart,
            left: 0,
            right: 0,
            bottom: _isLoaded ? 0 : -size.height,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 650),
              opacity: _isLoaded ? 1 : 0,
              child: ClipPath(
                clipper: _TopWaveClipper(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxHeight: size.height * 0.72,
                      minHeight: size.height * 0.55,
                    ),
                    padding: EdgeInsets.fromLTRB(24, 72, 24, bottomPad + 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2E8D5).withOpacity(0.72),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "Login to AgriVora",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1B1B1B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Enter your email or phone number and password\nto continue.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _SoftInput(
                            icon: Icons.alternate_email,
                            hint: "Email or phone number",
                            controller: _emailController,
                          ),
                          const SizedBox(height: 14),
                          _SoftInput(
                            icon: Icons.lock,
                            hint: "Password",
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.black54,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                    context, '/forgot-password');
                              },
                              child: const Text(
                                "Forgot password?",
                                style: TextStyle(
                                  color: Color(0xFF004D40),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF004D40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(34),
                                ),
                                elevation: 10,
                                shadowColor:
                                    const Color(0xFF004D40).withOpacity(0.35),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text(
                                      "Log In",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            "Don't have an account?",
                            style:
                                TextStyle(color: Colors.black54, fontSize: 14),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/signup'),
                            child: const Text(
                              "Create one",
                              style: TextStyle(
                                color: Color(0xFF004D40),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
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
}

class _TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 70);
    path.quadraticBezierTo(size.width * 0.25, 25, size.width * 0.55, 65);
    path.quadraticBezierTo(size.width * 0.82, 100, size.width, 55);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _SoftInput extends StatelessWidget {
  final IconData icon;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffix;

  const _SoftInput({
    required this.icon,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3EA).withOpacity(0.55),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFDDEEDD).withOpacity(0.85),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF004D40), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              cursorColor: const Color(0xFF004D40),
              style: const TextStyle(
                color: Color(0xFF1B1B1B),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                hintStyle: const TextStyle(
                  color: Color(0xFF6B6B6B),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}
