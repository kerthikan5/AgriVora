/// **ForgotPasswordPage**
/// Responsible for: Initiating password reset.
/// Role: Collects email, sends OTP request, and handles OTP verification.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

enum ForgotStep { email, otp, reset }

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  ForgotStep _currentStep = ForgotStep.email;
  bool _isLoading = false;
  String? _errorMessage;

  void _showError(String msg) {
    setState(() {
      _errorMessage = msg;
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _requestOTP() async {
    if (_emailController.text.isEmpty) {
      _showError("Please enter your email");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.requestResetOTP(_emailController.text);
      setState(() {
        _currentStep = ForgotStep.otp;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("OTP sent to your email"),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 6) {
      _showError("Please enter the 6-digit OTP");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.verifyResetOTP(
          _emailController.text, _otpController.text);
      setState(() {
        _currentStep = ForgotStep.reset;
        _isLoading = false;
      });
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<void> _resetPassword() async {
    if (_passwordController.text.length < 8) {
      _showError("Password must be at least 8 characters");
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError("Passwords do not match");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.resetPassword(
        _emailController.text,
        _otpController.text,
        _passwordController.text,
      );
      setState(() => _isLoading = false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Success"),
          content: const Text(
              "Your password has been reset successfully. You can now login with your new password."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(); // Back to login
              },
              child:
                  const Text("OK", style: TextStyle(color: Color(0xFF004D40))),
            )
          ],
        ),
      );
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

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

          // 🌿 Back Button
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 🌿 Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo_agrivora.png',
                    height: 120,
                  ),
                  const SizedBox(height: 30),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2E8D5).withOpacity(0.75),
                          borderRadius: BorderRadius.circular(30),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStepTitle(),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B1B1B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getStepSubtitle(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 30),
                            _buildFields(),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _getOnPressed(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF004D40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 5,
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : Text(
                                        _getButtonText(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case ForgotStep.email:
        return "Forgot Password?";
      case ForgotStep.otp:
        return "Verify OTP";
      case ForgotStep.reset:
        return "New Password";
    }
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case ForgotStep.email:
        return "Enter your email address to receive a 6-digit verification code.";
      case ForgotStep.otp:
        return "We have sent a code to ${_emailController.text}. Enter it below.";
      case ForgotStep.reset:
        return "Create a strong new password for your account.";
    }
  }

  String _getButtonText() {
    switch (_currentStep) {
      case ForgotStep.email:
        return "Send OTP";
      case ForgotStep.otp:
        return "Verify OTP";
      case ForgotStep.reset:
        return "Reset Password";
    }
  }

  VoidCallback _getOnPressed() {
    switch (_currentStep) {
      case ForgotStep.email:
        return _requestOTP;
      case ForgotStep.otp:
        return _verifyOTP;
      case ForgotStep.reset:
        return _resetPassword;
    }
  }

  Widget _buildFields() {
    switch (_currentStep) {
      case ForgotStep.email:
        return _buildTextField(_emailController, "Email Address",
            Icons.email_outlined, TextInputType.emailAddress);
      case ForgotStep.otp:
        return _buildTextField(_otpController, "6-Digit OTP",
            Icons.lock_clock_outlined, TextInputType.number);
      case ForgotStep.reset:
        return Column(
          children: [
            _buildTextField(_passwordController, "New Password",
                Icons.lock_outline, TextInputType.text,
                isObscure: true),
            const SizedBox(height: 20),
            _buildTextField(_confirmPasswordController, "Confirm Password",
                Icons.lock_outline, TextInputType.text,
                isObscure: true),
          ],
        );
    }
  }

  Widget _buildTextField(TextEditingController controller, String label,
      IconData icon, TextInputType type,
      {bool isObscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3E6).withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        obscureText: isObscure,
        style: const TextStyle(
            color: Color(0xFF1B1B1B), fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF004D40)),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black38),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}
