/// **PhStepScreen**
/// Responsible for: Getting pH value either manually or via BLE connected sensor.

import 'package:flutter/material.dart';

import '../main.dart'; // ScanSession
import 'image_step_screen.dart';

class PhStepScreen extends StatefulWidget {
  final ScanSession session;

  const PhStepScreen({
    super.key,
    required this.session,
  });

  @override
  State<PhStepScreen> createState() => _PhStepScreenState();
}

class _PhStepScreenState extends State<PhStepScreen> {
  late ScanSession _currentSession;
  final TextEditingController _phController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
    if (_currentSession.ph != null) {
      _phController.text = _currentSession.ph!.toString();
    }
  }

  @override
  void dispose() {
    _phController.dispose();
    super.dispose();
  }

  void _saveAndContinue() {
    final text = _phController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a pH value.')),
      );
      return;
    }

    final value = double.tryParse(text);
    if (value == null || value < 0 || value > 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid pH between 0–14.'),
        ),
      );
      return;
    }

    _currentSession = _currentSession.copyWith(ph: value);
    print('pH updated: ${_currentSession.toJson()}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageStepScreen(session: _currentSession),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 3 – pH'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter Soil pH',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You can connect the pH sensor or manually type the pH value from a soil test strip. '
              'For Dev1 we are using manual input.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _phController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'pH value',
                hintText: 'e.g. 6.5',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _saveAndContinue,
                child: const Text(
                  'Next – Image step',
                  style: TextStyle(
                    fontSize: 16,
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
