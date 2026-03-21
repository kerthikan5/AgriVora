/// **StartScanScreen**
/// Responsible for: Initiating the device-based soil scan flow.
/// Role: Starts a new ScanSession and navigates to the GPS step.

import 'package:flutter/material.dart';

import '../main.dart'; // to use ScanSession from main.dart
import 'gps_step_screen.dart'; // 👈 NEW: GPS step screen

class StartScanScreen extends StatelessWidget {
  const StartScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Scan'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'AgriVora Soil Scan',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This flow will collect your GPS location, pH value, and soil image, '
              'then contact the backend to get soil & weather summary and crop recommendations.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Steps:\n'
                '1. Get GPS location\n'
                '2. Enter or read pH\n'
                '3. Capture / upload soil image\n'
                '4. Analyze and view ranked crops & tips',
                style: TextStyle(fontSize: 14),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  // 1️⃣ Create a fresh ScanSession when user starts scan
                  final session = ScanSession.empty(
                    DateTime.now().millisecondsSinceEpoch.toString(),
                  );
                  print('New scan started: ${session.toJson()}');

                  // 2️⃣ Navigate to GPS step and pass this session
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GpsStepScreen(session: session),
                    ),
                  );
                },
                child: const Text(
                  'Start Scan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
