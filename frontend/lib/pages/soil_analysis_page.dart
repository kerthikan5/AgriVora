/// **SoilAnalysisPage**
/// Responsible for: Providing options for soil analysis methods.
/// Role: Allows the user to choose between IoT/BLE soil scanning or manual entry.
/// Dependencies: Navigates to StartScanScreen or ManualSoilAnalysisPage.

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/ble_service.dart';

class SoilAnalysisPage extends StatefulWidget {
  const SoilAnalysisPage({super.key});

  @override
  State<SoilAnalysisPage> createState() => _SoilAnalysisPageState();
}

enum AnalysisMode { image, manual, sensor }

class _SoilAnalysisPageState extends State<SoilAnalysisPage> {
  AnalysisMode _activeMode = AnalysisMode.image;

  // Image mode state
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzingImage = false;
  Map<String, dynamic>? _imageResult;

  // Manual mode state
  final TextEditingController _phController = TextEditingController();
  String _selectedSoilColor = 'Brown';
  String _selectedSoilTexture = 'Loamy';
  bool _isManualValid = false;

  // Sensor mode state
  double? _livePh;
  PhReading? _lastReading;
  BleStatus _bleStatus = const BleStatus(
    message: 'Initializing BLE…',
    state: BleConnectionState.scanning,
  );
  final List<StreamSubscription> _subs = [];
  bool _initializedArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedArgs) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['mode'] != null) {
        if (args['mode'] == 'manual') {
          _activeMode = AnalysisMode.manual;
        } else if (args['mode'] == 'sensor') {
          _activeMode = AnalysisMode.sensor;
        }
      }
      _initializedArgs = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _phController.addListener(_validateManualInput);

    // Initialize BLE logic but only connect if sensor mode is selected, or connect right away
    _subs.add(BleService().phStream.listen((ph) {
      if (mounted) setState(() => _livePh = ph);
    }));
    _subs.add(BleService().rawStream.listen((r) {
      if (mounted) setState(() => _lastReading = r);
    }));
    _subs.add(BleService().statusStream.listen((s) {
      if (mounted) setState(() => _bleStatus = s);
    }));

    // Auto-connect BLE
    BleService().startScanAndConnect();
  }

  @override
  void dispose() {
    _phController.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    BleService().disconnect();
    super.dispose();
  }

  // ─── Logic: Image ───
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _imageResult = null; // Clear previous result
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not access camera or gallery")),
      );
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;
    setState(() => _isAnalyzingImage = true);

    try {
      final result = await ApiService.analyzeSoilImage(_image!);
      if (mounted) {
        setState(() {
          _isAnalyzingImage = false;
          _imageResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  // ─── Logic: Manual ───
  void _validateManualInput() {
    final text = _phController.text.trim();
    if (text.isEmpty) {
      if (_isManualValid) setState(() => _isManualValid = false);
      return;
    }
    final ph = double.tryParse(text);
    final isValid = ph != null && ph >= 0 && ph <= 14;
    if (_isManualValid != isValid) {
      setState(() => _isManualValid = isValid);
    }
  }

  void _analyzeManual() {
    if (!_isManualValid) return;
    final ph = double.tryParse(_phController.text.trim());
    if (ph != null) {
      Navigator.pushNamed(context, '/crop-recom', arguments: {
        'ph': ph,
        'soilType': _selectedSoilTexture,
      });
    }
  }

  // ─── Main Build ───
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

          // ✅ Floating Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 55,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Predict Crops",
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
                      "Grow crops what you can.",
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.eco_rounded,
                      color: Colors.white, size: 28),
                ),
              ],
            ),
          ),

          // ✅ Large Wavy Glass Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _SoilWaveClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  height: size.height * 0.88,
                  padding: EdgeInsets.fromLTRB(16, 160, 16, bottomPad + 70),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2E8D5).withOpacity(0.68),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        _buildActiveModeCard(),
                        const SizedBox(height: 16),
                        if (_activeMode == AnalysisMode.image &&
                            _imageResult != null)
                          _buildImageResultCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 🧭 The Floating Navigation Bar

          // Full screen loading indicator
          if (_isAnalyzingImage)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text("Analyzing Soil Data...",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Toggle Section ───
  Widget _buildModeToggle() {
    return _GlassCardContainer(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToggleOption(
              AnalysisMode.image, "Image", Icons.camera_alt_outlined),
          const SizedBox(width: 8),
          _buildToggleOption(
              AnalysisMode.manual, "Manual", Icons.edit_note_rounded),
          const SizedBox(width: 8),
          _buildToggleOption(
              AnalysisMode.sensor, "Sensor", Icons.sensors_rounded),
        ],
      ),
    );
  }

  Widget _buildToggleOption(AnalysisMode mode, String label, IconData icon) {
    final isActive = _activeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2E7D32) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isActive ? Colors.transparent : Colors.black12),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isActive ? Colors.white : Colors.black54, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Active Mode Content ───
  Widget _buildActiveModeCard() {
    switch (_activeMode) {
      case AnalysisMode.image:
        return _buildImageInputCard();
      case AnalysisMode.manual:
        return _buildManualInputCard();
      case AnalysisMode.sensor:
        return _buildSensorInputCard();
    }
  }

  // ─── 1. Image Mode ───
  Widget _buildImageInputCard() {
    return _GlassCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text("Image Analysis (CNN Model)",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1B))),
          const SizedBox(height: 8),
          const Text("Upload a clear photo of your soil.",
              style: TextStyle(fontSize: 13, color: Colors.black54),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => _pickImage(ImageSource.gallery),
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF2E7D32).withOpacity(0.5),
                    width: 2,
                    style: BorderStyle.solid),
              ),
              child: _image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(_image!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_photo_alternate_rounded,
                            size: 40, color: Color(0xFF2E7D32)),
                        SizedBox(height: 8),
                        Text("Tap to upload from Gallery",
                            style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt,
                      color: Color(0xFF2E7D32), size: 18),
                  label: const Text("Camera",
                      style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _image == null || _isAnalyzingImage ? null : _analyzeImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                elevation: 4,
              ),
              child: const Text("Identify Soil type",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. Manual Mode ───
  Widget _buildManualInputCard() {
    return _GlassCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Manual Data Input",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1B))),
          const SizedBox(height: 8),
          const Text("Enter field properties manually.",
              style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 20),

          // Soil Color Dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedSoilColor,
            decoration: InputDecoration(
              labelText: "Soil Color",
              prefixIcon:
                  const Icon(Icons.palette_outlined, color: Color(0xFF2E7D32)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
            ),
            items: ['Brown', 'Black', 'Red', 'Yellow']
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (val) => setState(() => _selectedSoilColor = val!),
          ),
          const SizedBox(height: 16),

          // Soil Texture Dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedSoilTexture,
            decoration: InputDecoration(
              labelText: "Soil Texture",
              prefixIcon:
                  const Icon(Icons.landscape_rounded, color: Color(0xFF2E7D32)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
            ),
            items: ['Loamy', 'Clay', 'Sandy', 'Silt']
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (val) => setState(() => _selectedSoilTexture = val!),
          ),
          const SizedBox(height: 16),

          // pH Input
          TextField(
            controller: _phController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "pH Value (0.0 - 14.0)",
              prefixIcon:
                  const Icon(Icons.science_outlined, color: Color(0xFF2E7D32)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isManualValid ? _analyzeManual : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                elevation: 4,
              ),
              child: const Text("Recommend Crops",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. Sensor Mode ───
  Widget _buildSensorInputCard() {
    final st = _bleStatus.state;
    final isConn = st == BleConnectionState.connected;
    final isSim = st == BleConnectionState.simulating;

    Color phColor = const Color(0xFF2E7D32);
    String category = 'Unknown';
    if (_livePh != null) {
      if (_livePh! < 5.5) {
        phColor = const Color(0xFFD32F2F);
        category = 'Strongly Acidic';
      } else if (_livePh! < 6.5) {
        phColor = const Color(0xFFF57C00);
        category = 'Acidic';
      } else if (_livePh! < 7.5) {
        phColor = const Color(0xFF2E7D32);
        category = 'Neutral';
      } else if (_livePh! < 8.5) {
        phColor = const Color(0xFF1565C0);
        category = 'Alkaline';
      } else {
        phColor = const Color(0xFF6A1B9A);
        category = 'Strongly Alkaline';
      }
    }

    return _GlassCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("ESP32 Sensor Array",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1B1B))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isConn || isSim
                          ? const Color(0xFF2E7D32)
                          : Colors.redAccent)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                        isConn || isSim
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        size: 14,
                        color: isConn || isSim
                            ? const Color(0xFF2E7D32)
                            : Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(isConn || isSim ? "Connected" : "Disconnected",
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isConn || isSim
                                ? const Color(0xFF2E7D32)
                                : Colors.redAccent)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          if (_livePh != null) ...[
            Text(_livePh!.toStringAsFixed(2),
                style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: phColor,
                    letterSpacing: -1)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                  color: phColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(category,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: phColor)),
            ),
          ] else
            const SizedBox(
                height: 80,
                child: Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF2E7D32)))),
          const SizedBox(height: 16),
          Text(_bleStatus.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    BleService().startScanAndConnect();
                  },
                  icon: const Icon(Icons.refresh,
                      color: Color(0xFF2E7D32), size: 18),
                  label: const Text("Refresh Sensor",
                      style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _livePh != null
                  ? () {
                      Navigator.pushNamed(context, '/crop-recom', arguments: {
                        'ph': _livePh,
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                elevation: 4,
              ),
              child: const Text("Recommend Crops",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Image Result Card ───
  Widget _buildImageResultCard() {
    final result = _imageResult!;
    final soilType =
        (result['soil_type'] ?? result['texture'] ?? "Unknown").toString();
    final confidence = result['confidence'] != null
        ? (result['confidence'] as num).toDouble()
        : 0.0;

    // Condition mapping
    String condition = "Moderate";
    Color condColor = const Color(0xFFF57C00);
    if (confidence >= 0.7) {
      condition = "Good";
      condColor = const Color(0xFF2E7D32);
    } else if (confidence < 0.4) {
      condition = "Poor";
      condColor = Colors.redAccent;
    }

    return _GlassCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              const Text("Analysis Complete",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1B1B))),
            ],
          ),
          const SizedBox(height: 16),
          _buildResultRow("Detected Soil Type", soilType, isBold: true),
          _buildResultRow("Condition", condition, color: condColor),
          const SizedBox(height: 16),
          const Text("Soil Health Score",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: confidence,
                    minHeight: 8,
                    backgroundColor: Colors.black12,
                    color: condColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text("${(confidence * 100).toInt()}%",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: condColor)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome,
                    color: Color(0xFF2E7D32), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      "AI suggests $soilType soil is often suitable for various crops but requires verification with pH levels.",
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF1B5E20), height: 1.4)),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () async {
                if (_imageResult != null) {
                  final data = {
                    "texture": soilType,
                    "confidence": confidence,
                    "type": "Soil Analysis",
                  };
                  await ApiService.saveToHistory(data);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Saved to history")));
                }
              },
              child: const Text("Save to History",
                  style: TextStyle(
                      color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  color: color ?? const Color(0xFF1B1B1B),
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─── Reusable Container ───
class _GlassCardContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const _GlassCardContainer({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
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

// ─── Clipper ───
class _SoilWaveClipper extends CustomClipper<Path> {
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
