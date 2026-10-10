
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for the simplified ESP32 RS485 + Web Control firmware.
///
/// This firmware is intentionally minimal compared to the old v3.3 REST
/// build: no relays, no LD2410 occupancy, no fumigation state machine, no
/// differential pressure, no fault reporting. It only tracks temperature,
/// humidity, their setpoints, and an "IOT timer", all bridged to a slave
/// device over RS485 using a `{KEY:value,...}` packet.
///
/// Endpoints (port 8080, no `/api/` prefix):
///   GET  /sensor-data     -> converted float readings + status (main poll)
///   GET  /connection-test -> lightweight reachability check
///   GET  /status          -> wifi/AP state
///   GET  /data            -> raw universalDataString
///   POST /control         -> form-encoded setpoint writes
///   GET  /restart         -> reboots the device
class ESP32Provider with ChangeNotifier {
  // ── Connection ────────────────────────────────────────────────────────
  String _esp32IP = "192.168.4.1:8080";
  Timer? _pollingTimer;
  bool _isConnected = false;
  int _consecutiveFailures = 0;
  static const int _maxConsecutiveFailures = 5;
  bool _isFetching = false;

  final http.Client _httpClient = http.Client();

  String get esp32BaseUrl => "http://$_esp32IP";
  String get esp32IP => _esp32IP;
  bool get isConnected => _isConnected;

  // ── Sensor readings ───────────────────────────────────────────────────
  String _currentTemperature = "0.0";
  String _currentHumidity = "0.0";

  String get currentTemperature => _currentTemperature;
  String get currentHumidity => _currentHumidity;
  double get currentTemperatureAsDouble =>
      double.tryParse(_currentTemperature) ?? 0.0;
  double get currentHumidityAsDouble =>
      double.tryParse(_currentHumidity) ?? 0.0;

  // ── Setpoints ─────────────────────────────────────────────────────────
  String _temperatureSetpoint = "26.6";
  String _humiditySetpoint = "50.0";
  double _pendingTemperature = 26.6;

  String get temperatureSetpoint => _temperatureSetpoint;
  String get humiditySetpoint => _humiditySetpoint;
  double get temperatureSetpointAsDouble =>
      double.tryParse(_temperatureSetpoint) ?? 26.6;
  double get humiditySetpointAsDouble =>
      double.tryParse(_humiditySetpoint) ?? 50.0;
  double get pendingTemperature => _pendingTemperature;

  // ── IOT timer ─────────────────────────────────────────────────────────
  int _iotTimer = 60;
  int get iotTimer => _iotTimer;

  // ── Misc status ───────────────────────────────────────────────────────
  String _srWsl = "";
  String _wifiMode = "unknown"; // "ap" | "station"
  String _ipAddress = "";
  bool _dataReceived = false; // slave has ever sent a valid RS485 packet

  String get srWsl => _srWsl;
  String get wifiMode => _wifiMode;
  String get ipAddress => _ipAddress;
  bool get dataReceived => _dataReceived;
  bool get isApMode => _wifiMode == "ap";

  // ── Setpoint guards (avoid poll clobbering a just-sent write) ──────────
  static const Duration _setpointGuardDuration = Duration(seconds: 15);
  DateTime? _temperatureSetpointGuardUntil;
  DateTime? _humiditySetpointGuardUntil;
  DateTime? _iotTimerGuardUntil;

  bool get _isTemperatureGuardActive =>
      _temperatureSetpointGuardUntil != null &&
      DateTime.now().isBefore(_temperatureSetpointGuardUntil!);
  bool get _isHumidityGuardActive =>
      _humiditySetpointGuardUntil != null &&
      DateTime.now().isBefore(_humiditySetpointGuardUntil!);
  bool get _isIotTimerGuardActive =>
      _iotTimerGuardUntil != null &&
      DateTime.now().isBefore(_iotTimerGuardUntil!);

  // ── Init ─────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    await loadSavedIpAddress();
    await _loadSavedSetpoints();
    startPolling();
  }

  Future<void> loadSavedIpAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString("espIp");
      if (savedIp != null && savedIp.isNotEmpty) {
        _esp32IP = savedIp.contains(':') ? savedIp : "$savedIp:8080";
        print("✅ Loaded ESP32 IP from SharedPreferences: $_esp32IP");
      } else {
        print("⚠️ No saved ESP32 IP found, using default: $_esp32IP");
      }
    } catch (e) {
      print("❌ Error loading ESP32 IP from SharedPreferences: $e");
    }
  }

  Future<void> _loadSavedSetpoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTemp = prefs.getDouble("tempSetpoint");
      if (savedTemp != null) {
        _temperatureSetpoint = savedTemp.toStringAsFixed(1);
        _pendingTemperature = savedTemp;
      }
      final savedHumidity = prefs.getDouble("humiditySetpoint");
      if (savedHumidity != null) {
        _humiditySetpoint = savedHumidity.toStringAsFixed(1);
      }
      final savedTimer = prefs.getInt("iotTimer");
      if (savedTimer != null) {
        _iotTimer = savedTimer;
      }
    } catch (e) {
      print("❌ Error loading saved setpoints: $e");
    }
  }

  Future<void> updateEsp32Ip(String newIp) async {
    try {
      String cleanIp = newIp.split(':')[0];
      _esp32IP = "$cleanIp:8080";
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("espIp", cleanIp);
      print("✅ ESP32 IP updated to: $_esp32IP");

      _isConnected = false;
      _consecutiveFailures = 0;
      notifyListeners();

      stopPolling();
      startPolling();
    } catch (e) {
      print("❌ Error saving ESP32 IP: $e");
    }
  }

  // ── Temperature ──────────────────────────────────────────────────────
  void updatePendingTemperature(double value) {
    _pendingTemperature = value;
    notifyListeners();
  }

  Future<void> setTemperature(double temperature) async {
    print('🌡️ setTemperature called: ${temperature.toStringAsFixed(1)}°C');

    _temperatureSetpoint = temperature.toStringAsFixed(1);
    _pendingTemperature = temperature;
    _temperatureSetpointGuardUntil = DateTime.now().add(_setpointGuardDuration);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble("tempSetpoint", temperature);
    } catch (e) {
      print("❌ Failed to save temp setpoint: $e");
    }

    notifyListeners();

    // Firmware stores setpoint as value×10, zero-padded to 3 digits.
    final String raw = (temperature * 10).round().toString().padLeft(3, '0');
    try {
      await _postControl({'S_TEMP_SETPT': raw});
    } catch (e) {
      // Write didn't actually reach the device — drop the guard immediately
      // so the next poll corrects the displayed value instead of holding
      // this false optimistic value for the full guard window.
      _temperatureSetpointGuardUntil = null;
      rethrow;
    }
  }

  // ── Humidity ─────────────────────────────────────────────────────────
  Future<void> setHumiditySetpoint(double humidity) async {
    print('💧 setHumiditySetpoint called: $humidity%');

    _humiditySetpoint = humidity.toStringAsFixed(1);
    _humiditySetpointGuardUntil = DateTime.now().add(_setpointGuardDuration);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble("humiditySetpoint", humidity);
    } catch (e) {
      print("❌ Failed to save humidity setpoint: $e");
    }

    notifyListeners();

    final String raw = (humidity * 10).round().toString().padLeft(3, '0');
    try {
      await _postControl({'S_RH_SETPT': raw});
    } catch (e) {
      _humiditySetpointGuardUntil = null;
      rethrow;
    }
  }

  // ── IOT timer ─────────────────────────────────────────────────────────
  Future<void> setIotTimer(int seconds) async {
    print('⏱️ setIotTimer called: $seconds s');

    _iotTimer = seconds;
    _iotTimerGuardUntil = DateTime.now().add(_setpointGuardDuration);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt("iotTimer", seconds);
    } catch (e) {
      print("❌ Failed to save IOT timer: $e");
    }

    notifyListeners();

    final String raw = seconds.toString().padLeft(4, '0');
    try {
      await _postControl({'S_IOT_TIMER': raw});
    } catch (e) {
      _iotTimerGuardUntil = null;
      rethrow;
    }
  }

  /// Throws on failure so callers (setTemperature/setHumiditySetpoint/
  /// setIotTimer) don't silently report success when the write never
  /// actually reached the device.
  Future<void> _postControl(Map<String, String> fields) async {
    try {
      final response = await _httpClient
          .post(Uri.parse('$esp32BaseUrl/control'), body: fields)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print('✅ /control update confirmed: $fields');
      } else {
        print('❌ /control failed: ${response.statusCode} ${response.body}');
        throw Exception(
          '/control returned ${response.statusCode}: ${response.body}',
        );
      }
    } on Exception {
      rethrow;
    } catch (e) {
      print("❌ /control error: $e");
      throw Exception('/control request failed: $e');
    }
  }

  // ── Polling ──────────────────────────────────────────────────────────
  void startPolling() {
    stopPolling();

    Future.delayed(const Duration(milliseconds: 500), () {
      _checkConnection();
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_isFetching) {
        print('⚠️ Previous poll still in progress, skipping...');
        return;
      }

      await _checkConnection();
      if (_isConnected) {
        await _fetchSensorData();
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _checkConnection() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$esp32BaseUrl/connection-test'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        _consecutiveFailures = 0;
        if (!_isConnected) {
          _isConnected = true;
          print("✅ Connected to ESP32 at $_esp32IP");
          notifyListeners();
        }
      } else {
        _handleConnectionFailure(
          'Unexpected status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      _handleConnectionFailure(e.toString());
    }
  }

  void _handleConnectionFailure(String error) {
    _consecutiveFailures++;

    if (_consecutiveFailures % 3 == 0) {
      print(
        '❌ Connection failure $_consecutiveFailures/$_maxConsecutiveFailures: $error',
      );
    }

    if (_consecutiveFailures >= _maxConsecutiveFailures && _isConnected) {
      _isConnected = false;
      print(
        "❌ Disconnected from ESP32 after $_maxConsecutiveFailures consecutive failures",
      );
      notifyListeners();
    }
  }

  Future<void> refreshData() async {
    await _checkConnection();
    if (_isConnected) await _fetchSensorData();
  }

  /// Back-compat alias used by screens that just want a fresh read.
  Future<void> requestTemperatureStatus() => refreshData();

  // ── /sensor-data (single-shot poll: readings + setpoints + status) ─────
  Future<void> _fetchSensorData() async {
    if (!_isConnected || _isFetching) return;

    _isFetching = true;
    try {
      final response = await _httpClient
          .get(Uri.parse('$esp32BaseUrl/sensor-data'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return;
      final data = json.decode(response.body);

      if (data['temperature'] != null) {
        _currentTemperature = (data['temperature'] as num).toStringAsFixed(1);
      }
      if (data['humidity'] != null) {
        _currentHumidity = (data['humidity'] as num).toStringAsFixed(1);
      }
      if (data['temp_setpoint'] != null && !_isTemperatureGuardActive) {
        final val = (data['temp_setpoint'] as num).toDouble();
        _temperatureSetpoint = val.toStringAsFixed(1);
        _pendingTemperature = val;
      }
      if (data['humidity_setpoint'] != null && !_isHumidityGuardActive) {
        final val = (data['humidity_setpoint'] as num).toDouble();
        _humiditySetpoint = val.toStringAsFixed(1);
      }
      if (data['iot_timer'] != null && !_isIotTimerGuardActive) {
        _iotTimer = (data['iot_timer'] as num).toInt();
      }
      if (data['sr_wsl'] != null) {
        _srWsl = data['sr_wsl'].toString();
      }
      if (data['wifi_mode'] != null) {
        _wifiMode = data['wifi_mode'].toString();
      }
      if (data['ip_address'] != null) {
        _ipAddress = data['ip_address'].toString();
      }
      if (data['data_received'] != null) {
        _dataReceived = data['data_received'] == true;
      }

      notifyListeners();
    } catch (e) {
      print('⚠️ /sensor-data fetch error: $e');
    } finally {
      _isFetching = false;
    }
  }

  // ── WiFi provisioning ────────────────────────────────────────────────
  Future<bool> saveWifiCredentials(String ssid, String password) async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse('$esp32BaseUrl/save-wifi'),
            body: {'ssid': ssid, 'password': password},
          )
          .timeout(const Duration(seconds: 5));
      // Device restarts itself after saving, so a non-200 here isn't
      // necessarily a failure — but 200 confirms it accepted the request.
      return response.statusCode == 200;
    } catch (e) {
      print("❌ saveWifiCredentials error: $e");
      return false;
    }
  }

  // ── Restart ──────────────────────────────────────────────────────────
  Future<bool> restartDevice() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$esp32BaseUrl/restart'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print("❌ restartDevice error: $e");
      return false;
    }
  }

  @override
  void dispose() {
    stopPolling();
    _httpClient.close();
    super.dispose();
  }
}
