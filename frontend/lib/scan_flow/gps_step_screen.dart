/// **GpsStepScreen**
/// Responsible for: Fetching GPS coords for the scan session.

import 'package:flutter/material.dart';

import '../main.dart'; // to use ScanSession
import 'ph_step_screen.dart'; // we'll create this next

class GpsStepScreen extends StatefulWidget {
  final ScanSession session;

  const GpsStepScreen({
    super.key,
    required this.session,
  });

  @override
  State<GpsStepScreen> createState() => _GpsStepScreenState();
}

class _GpsStepScreenState extends State<GpsStepScreen> {
  late ScanSession _currentSession;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
  }

  Future<void> _fakeGetLocation() async {
    // TODO: replace this with real GPS (geolocator) later
    setState(() {
      _isFetching = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _currentSession = _currentSession.copyWith(
        latitude: 6.9271, // Colombo (just as sample)
        longitude: 79.8612,
      );
      _isFetching = false;
    });

    print('GPS updated: ${_currentSession.toJson()}');
  }

  void _goNext() {
    if (_currentSession.latitude == null || _currentSession.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fetch GPS location before continuing.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhStepScreen(session: _currentSession),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lat = _currentSession.latitude;
    final lon = _currentSession.longitude;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 2 – GPS'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Get GPS Location',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'We use your GPS location to fetch soil and weather data from APIs '
              'like SoilGrids and Open-Meteo. For now this uses a sample location.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current coordinates',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lat == null || lon == null
                        ? 'Not fetched yet'
                        : 'Latitude: ${lat.toStringAsFixed(4)}, '
                            'Longitude: ${lon.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
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
                onPressed: _isFetching ? null : _fakeGetLocation,
                child: _isFetching
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Get GPS (sample)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _goNext,
                child: const Text(
                  'Next – pH step',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
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
