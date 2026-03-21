/// **ApiService**
/// Responsible for: All backend API calls in the application.
/// Role: Encapsulates network requests, dynamic baseUrl discovery, error handling, and JSON parsing.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'session_service.dart';

class ApiService {
  // ─────────────────────────────────────────────────────────────
  // Dynamic base-URL discovery
  // ─────────────────────────────────────────────────────────────
  // Ordered candidates:
  //   1. 127.0.0.1        — localhost via `adb reverse tcp:8000 tcp:8000` (USB cable) ← preferred
  //   2. 192.168.8.104    — PC's current LAN/Wi-Fi IP (update if your router changes)
  //   3. 172.20.10.4      — PC hotspot IP (iPhone personal hotspot subnet)
  //   4. 172.20.10.2      — alternate hotspot gateway
  //   5. 172.21.96.1      — secondary hotspot/VPN subnet
  //   6. 10.0.2.2         — Android emulator loopback to host PC
  static const List<String> _candidateBaseUrls = [
    "https://agrivora-production.up.railway.app",
  ];

  static String? _resolvedBaseUrl;
  static bool _isResolving = false;
  static final List<Completer<String>> _resolveWaiters = [];

  /// Trigger used to notify the UI (HistoryPage) that it needs to refresh
  static final ValueNotifier<int> historyRefreshTrigger = ValueNotifier(0);

  /// Returns the cached working base URL, auto-discovering on first call.
  /// Retries up to [maxAttempts] times with [retryDelay] between attempts so
  /// the app waits for the backend to start rather than giving up immediately.
  static Future<String> getBaseUrl({int maxAttempts = 3}) async {
    if (kIsWeb) return "https://agrivora-production.up.railway.app";
    if (_resolvedBaseUrl != null) return _resolvedBaseUrl!;

    if (_isResolving) {
      final c = Completer<String>();
      _resolveWaiters.add(c);
      return c.future;
    }

    _isResolving = true;
    String found = _candidateBaseUrls.first;
    bool connected = false;

    outer:
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      for (final url in _candidateBaseUrls) {
        try {
          final r = await http.get(Uri.parse('$url/health'), headers: {
            'Accept': 'application/json'
          }).timeout(const Duration(seconds: 6));
          if (r.statusCode == 200) {
            found = url;
            connected = true;
            debugPrint(
                '[ApiService] ✅ Connected to backend at $url (attempt $attempt)');
            break outer;
          }
        } catch (_) {
          debugPrint('[ApiService] ❌ $url unreachable (attempt $attempt)');
        }
      }
      if (!connected && attempt < maxAttempts) {
        debugPrint(
            '[ApiService] ⏳ Retrying in 2 s... (attempt $attempt/$maxAttempts)');
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!connected) {
      debugPrint(
          '[ApiService] ⚠️ All candidates failed after $maxAttempts attempts. Using ${_candidateBaseUrls.first} as fallback.');
    }

    _resolvedBaseUrl = found;
    _isResolving = false;
    for (final c in _resolveWaiters) {
      c.complete(found);
    }
    _resolveWaiters.clear();
    return found;
  }

  /// Force re-discovery on next request (call after a connection failure).
  static void resetBaseUrl() {
    _resolvedBaseUrl = null;
    debugPrint(
        '[ApiService] Base URL reset — will re-discover on next request');
  }

  /// Sync getter — safe fallback. Use getBaseUrl() in async contexts.
  static String get baseUrl => _resolvedBaseUrl ?? _candidateBaseUrls.first;

  // ─────────────────────────────────────────────────────────────
  // Session
  // ─────────────────────────────────────────────────────────────
  static String? userId;
  static String? userName;
  static String? userEmail;
  static String? userPhone;

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static String _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      final detail = decoded['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null)
          return first['msg'].toString();
        return detail.toString();
      }
      if (decoded['message'] != null) return decoded['message'].toString();
      if (decoded['error'] != null) return decoded['error'].toString();
      return "Server error (${response.statusCode})";
    } catch (_) {
      return "Server error (${response.statusCode}): ${response.body}";
    }
  }

  static dynamic _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Authentication
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
      String emailOrPhone, String password) async {
    try {
      final base = await getBaseUrl();
      final body = {
        'email_or_phone': emailOrPhone.trim(),
        'password': password.trim(),
      };

      final response = await http
          .post(
            Uri.parse('$base/api/auth/login'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        userId = (decoded['user_id'] ?? decoded['userId'])?.toString();
        userName = decoded['full_name']?.toString();
        userEmail = decoded['email']?.toString();
        userPhone = decoded['phone']?.toString();
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } on TimeoutException {
      throw Exception('Connection timed out. Check if backend is running.');
    } on SocketException catch (e) {
      resetBaseUrl();
      throw Exception(
          'Cannot reach backend: ${e.message}. Check your connection.');
    } catch (e) {
      if (e.toString().contains('ClientException') ||
          e.toString().contains('SocketException')) {
        resetBaseUrl();
      }
      throw Exception('Connection error: $e');
    }
  }

  static Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final base = await getBaseUrl();
      final pw = password.trim();
      // ignore: avoid_print
      print(
          'SIGNUP password chars=${pw.length}, bytes=${utf8.encode(pw).length}');

      final body = {
        'full_name': fullName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': pw,
      };
      // ignore: avoid_print
      print('SIGNUP body => ${jsonEncode(body)}');

      final response = await http
          .post(
            Uri.parse('$base/api/auth/signup'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } on TimeoutException {
      throw Exception('Connection timed out. Check if backend is running.');
    } on SocketException catch (e) {
      resetBaseUrl();
      throw Exception('Cannot reach backend: ${e.message}.');
    } catch (e) {
      if (e.toString().contains('ClientException')) resetBaseUrl();
      throw Exception('Connection error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Forgot Password
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> requestResetOTP(String email) async {
    try {
      final base = await getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$base/api/auth/forgot-password/request-otp'),
            headers: _headers,
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } catch (e) {
      if (e.toString().contains('ClientException')) resetBaseUrl();
      throw Exception('Error requesting OTP: $e');
    }
  }

  static Future<Map<String, dynamic>> verifyResetOTP(
      String email, String otp) async {
    try {
      final base = await getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$base/api/auth/forgot-password/verify-otp'),
            headers: _headers,
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'otp': otp.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } catch (e) {
      if (e.toString().contains('ClientException')) resetBaseUrl();
      throw Exception('Error verifying OTP: $e');
    }
  }

  static Future<Map<String, dynamic>> resetPassword(
      String email, String otp, String newPassword) async {
    try {
      final base = await getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$base/api/auth/forgot-password/reset'),
            headers: _headers,
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'otp': otp.trim(),
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } catch (e) {
      if (e.toString().contains('ClientException')) resetBaseUrl();
      throw Exception('Error resetting password: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Profile / Settings
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phone,
  }) async {
    if (userId == null) throw Exception('User not logged in');
    try {
      final base = await getBaseUrl();
      final body = <String, dynamic>{};
      if (fullName != null) body['full_name'] = fullName;
      if (phone != null) body['phone'] = phone;

      final response = await http
          .put(
            Uri.parse('$base/api/users/profile/$userId'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        if (fullName != null) userName = fullName;
        if (phone != null) userPhone = phone;
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } catch (e) {
      if (e.toString().contains('ClientException')) resetBaseUrl();
      throw Exception('Error updating profile: $e');
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (userId == null) throw Exception('User not logged in');
    try {
      final base = await getBaseUrl();
      final response = await http
          .put(
            Uri.parse('$base/api/users/$userId/change-password'),
            headers: _headers,
            body: jsonEncode({
              'old_password': oldPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } catch (e) {
      if (e.toString().contains('ClientException')) resetBaseUrl();
      throw Exception('Error changing password: $e');
    }
  }

  /// Clears the in-memory session AND persisted prefs
  static Future<void> logout() async {
    userId = null;
    userName = null;
    userEmail = null;
    userPhone = null;
    await SessionService.clearSession();
  }

  // ─────────────────────────────────────────────────────────────
  // History
  // ─────────────────────────────────────────────────────────────
  static Future<void> saveToHistory(Map<String, dynamic> data) async {
    if (userId == null) return;
    data['userId'] = userId;
    try {
      final base = await getBaseUrl();
      await http
          .post(
            Uri.parse('$base/history/save'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));
      historyRefreshTrigger.value++;
    } catch (e) {
      debugPrint("Failed to save to history: $e");
    }
  }

  static Future<List<dynamic>> getUserHistory() async {
    if (userId == null) throw Exception('User not logged in');
    try {
      final base = await getBaseUrl();
      final response = await http
          .get(Uri.parse('$base/history/$userId'), headers: _headers)
          .timeout(const Duration(seconds: 15));

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        return List<dynamic>.from(decoded['data'] ?? []);
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } catch (e) {
      if (e.toString().contains('ClientException')) resetBaseUrl();
      throw Exception('Error fetching history: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Recommendations (manual soil form)
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getRecommendations({
    required String soilType,
    required double ph,
    required double temperature,
    required double rainfall,
    required double humidity,
  }) async {
    if (userId == null) throw Exception('User not logged in');
    try {
      final base = await getBaseUrl();
      final body = {
        'user_id': userId,
        'soil_type': soilType,
        'ph': ph,
        'temperature': temperature,
        'rainfall': rainfall,
        'humidity': humidity,
      };

      final response = await http
          .post(
            Uri.parse('$base/recommend'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        historyRefreshTrigger.value++;
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } on TimeoutException {
      throw Exception('Connection timed out. Check if backend is running.');
    } catch (e) {
      if (e.toString().contains('ClientException')) resetBaseUrl();
      throw Exception('Connection error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Location Summary (Weather + Soil)
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getLocationSummary(
      double lat, double lon) async {
    try {
      final base = await getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$base/location/summary'),
            headers: _headers,
            body: jsonEncode({'lat': lat, 'lon': lon}),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        return Map<String, dynamic>.from(decoded['data']);
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } on TimeoutException {
      throw Exception('Connection timed out. Check if backend is running.');
    } catch (e) {
      if (e.toString().contains('ClientException')) resetBaseUrl();
      throw Exception('Connection error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Soil Image Analysis (CNN)
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> analyzeSoilImage(File imageFile) async {
    // TF loads the model on first request — can take 60-90 s cold start.
    const kAnalysisTimeout = Duration(seconds: 120);
    try {
      final base = await getBaseUrl();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$base/image/texture'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final streamedResponse = await request.send().timeout(kAnalysisTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        historyRefreshTrigger.value++;
        return Map<String, dynamic>.from(decoded['data']);
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } on TimeoutException {
      throw Exception('Analysis timed out after 120 s.\n'
          'The first scan takes longer while the AI model loads.\n'
          'Please try again — it will be much faster.');
    } catch (e) {
      if (e.toString().contains('ClientException')) resetBaseUrl();
      throw Exception('Upload error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Crop Recommendation (LightGBM)
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> predictCropLGBM({
    required double temperature,
    required double humidity,
    required double rainfall,
    required double ph,
    required double nitrogen,
    required double carbon,
    required String soilType,
  }) async {
    try {
      final base = await getBaseUrl();
      final body = {
        'user_id': userId,
        'temperature': temperature,
        'humidity': humidity,
        'rainfall': rainfall,
        'ph': ph,
        'nitrogen': nitrogen,
        'carbon': carbon,
        'soil_type': soilType,
      };

      final response = await http
          .post(
            Uri.parse('$base/crop/recommend'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 && decoded is Map) {
        // Standard envelope: { "success": true, "data": {...} }
        if (decoded['success'] == true && decoded['data'] is Map) {
          historyRefreshTrigger.value++;
          return Map<String, dynamic>.from(decoded['data'] as Map);
        }
        // Fallback: flat response with recommended_crop directly (legacy)
        if (decoded.containsKey('recommended_crop')) {
          historyRefreshTrigger.value++;
          return Map<String, dynamic>.from(decoded);
        }
        throw Exception(_extractErrorMessage(response));
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } on TimeoutException {
      throw Exception('Crop recommendation timed out.');
    } catch (e) {
      if (e.toString().contains('ClientException')) resetBaseUrl();
      throw Exception('Connection error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Chat AI  (uses same resolved URL, no separate IP list needed)
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> askChatAI(String message) async {
    try {
      final base = await getBaseUrl();
      final response = await http
          .post(
            Uri.parse('$base/chat'),
            headers: _headers,
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 60));

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        return Map<String, dynamic>.from(decoded['data']);
      } else if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == false) {
        throw Exception(decoded['error'] ?? 'Unknown backend error');
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } on TimeoutException {
      throw Exception('Connection timed out. Ensure backend is running.');
    } catch (e) {
      if (e.toString().contains('ClientException')) resetBaseUrl();
      throw Exception('Chat error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Sensor (pH / BLE)
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> searchDevice() async {
    try {
      final base = await getBaseUrl();
      final response = await http
          .get(Uri.parse('$base/ph/search_device'), headers: _headers)
          .timeout(const Duration(seconds: 15));

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        return Map<String, dynamic>.from(decoded['data']);
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } catch (e) {
      if (e.toString().contains('ClientException')) resetBaseUrl();
      throw Exception('Error searching device: $e');
    }
  }

  static Future<Map<String, dynamic>> getLivePh() async {
    try {
      final base = await getBaseUrl();
      final uid = userId ?? "guest";
      final response = await http
          .get(Uri.parse('$base/ph/live/$uid'), headers: _headers)
          .timeout(const Duration(seconds: 15));

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        return Map<String, dynamic>.from(decoded['data']);
      } else {
        throw Exception(_extractErrorMessage(response));
      }
    } catch (e) {
      if (e.toString().contains('ClientException')) resetBaseUrl();
      throw Exception('Error fetching live pH: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Health check
  // ─────────────────────────────────────────────────────────────
  static Future<bool> checkHealth() async {
    try {
      final base = await getBaseUrl();
      final response = await http
          .get(Uri.parse('$base/health'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = _safeJsonDecode(response.body);
        return decoded is Map && decoded['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
