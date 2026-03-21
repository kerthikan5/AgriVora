/// **SignUpPage**
/// Responsible for: New user registration.
/// Role: Collects user details, validates form input, and hits the signup endpoint.
/// API Dependency: /api/auth/signup

import 'dart:ui';
import 'dart:convert'; // ✅ added for utf8.encode
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _isLoaded = true);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ✅ FIXED SIGNUP METHOD (debug bytes + cleaner error display)
  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return;
    }

    // ✅ DEBUG: bcrypt limit is 72 BYTES (not characters)
    final pwBytes = utf8.encode(password).length;
    // ignore: avoid_print
    print("SIGNUP password chars=${password.length}, bytes=$pwBytes");

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.signup(
        fullName: name,
        email: email,
        phone: phone,
        password: password,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']?.toString() ?? 'Account created!'),
        ),
      );

      Navigator.pop(context); // Go back to login
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().replaceAll('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 4),
        ),
      );
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
          // ✅ background
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_fields.png',
              fit: BoxFit.cover,
            ),
          ),

          // ✅ logo
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

          // ✅ bottom wavy panel (animated)
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
                      maxHeight: size.height * 0.80,
                      minHeight: size.height * 0.62,
                    ),
                    padding: EdgeInsets.fromLTRB(24, 68, 24, bottomPad + 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2E8D5).withOpacity(0.72),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "Create Account",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1B1B1B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              "Enter your details to get started.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _SoftInput(
                            icon: Icons.person,
                            hint: "Full name",
                            controller: _nameController,
                          ),
                          const SizedBox(height: 12),
                          _SoftInput(
                            icon: Icons.alternate_email,
                            hint: "Email address",
                            controller: _emailController,
                          ),
                          const SizedBox(height: 12),
                          _SoftInput(
                            icon: Icons.phone,
                            hint: "Phone number",
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          _SoftInput(
                            icon: Icons.lock,
                            hint: "Create password",
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.black45,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signup,
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
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      "Sign Up",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Already have an account?",
                            style:
                                TextStyle(color: Colors.black54, fontSize: 14),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Log in",
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

/// ✅ same wavy top style as login
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

/// ✅ same input style as login (icon in circle + soft green field)
class _SoftInput extends StatelessWidget {
  final IconData icon;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _SoftInput({
    required this.icon,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
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
              keyboardType: keyboardType,
              obscureText: obscureText,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.black45),
                border: InputBorder.none,
              ),
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}
