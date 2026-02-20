import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class ESP32State with ChangeNotifier {
  final String baseUrl = 'http://192.168.1.143:8080';

  Map<String, String> _data = {};
  List<bool> _lights = List.generate(10, (index) => false);
  List<int> _lightIntensities = List.generate(10, (index) => 0);
  List<bool> _sensorStatus = List.generate(7, (index) => false);
  Timer? _timer;
  bool _isLoading = false;
  String? _error;

  // Getters
  Map<String, String> get data => _data;
  List<bool> get lights => _lights;
  List<int> get lightIntensities => _lightIntensities;
  List<bool> get sensorStatus => _sensorStatus;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ESP32State() {
    _startPolling();
  }

  void _startPolling() {
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    if (_isLoading) return;

    _setLoading(true);
    _error = null;

    try {
      final response = await http.get(Uri.parse('$baseUrl/data'));
      if (response.statusCode == 200) {
        final raw = response.body;
        final newData = _parseDataString(raw);
        _updateState(newData);
      } else {
        _error = 'Failed to fetch data: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error fetching data: $e';
    } finally {
      _setLoading(false);
    }
  }

  Map<String, String> _parseDataString(String s) {
    s = s.trim();
    if (s.startsWith('{')) s = s.substring(1);
    if (s.endsWith('}')) s = s.substring(0, s.length - 1);

    final Map<String, String> m = {};
    final parts = s.split(',');

    for (var p in parts) {
      if (p.isNotEmpty && p.contains(':')) {
        final kv = p.split(':');
        if (kv.length == 2) {
          final key = kv[0].trim();
          final value = kv[1].trim();
          m[key] = value;
        }
      }
    }
    return m;
  }

  void _updateState(Map<String, String> newData) {
    _data = newData;

    // Update light states for 10 lights
    for (int i = 0; i < 10; i++) {
      final lightKey = 'S_Light_${i + 1}_ON_OFF';
      _lights[i] = newData[lightKey] == '1';
    }

    // Update light intensities for 10 lights
    for (int i = 0; i < 10; i++) {
      final intensityKey = 'S_Light_${i + 1}_Intensity';
      final intensityValue = newData[intensityKey] ?? '0';
      _lightIntensities[i] = int.tryParse(intensityValue) ?? 0;
    }

    // Update sensor status - 1 = Full, 0 = Empty
    for (int i = 0; i < 7; i++) {
      final sensorKey = 'F_Sensor_${i + 1}_FAULT_BIT';
      _sensorStatus[i] = newData[sensorKey] == '1';
    }

    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> updateValue(String key, String value) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await http.get(Uri.parse('$baseUrl/update?$key=$value'));
      if (response.statusCode == 302 || response.statusCode == 200) {
        await _fetchData(); // Refresh data after update
      } else {
        _error = 'Failed to update: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error updating: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateLight(int lightNumber, bool value) async {
    await updateValue('S_Light_${lightNumber}_ON_OFF', value ? '1' : '0');
  }

  Future<void> updateLightIntensity(int lightNumber, int intensity) async {
    await updateValue(
      'S_Light_${lightNumber}_Intensity',
      intensity.toString().padLeft(3, '0'),
    );
  }

  Future<void> updateTemperatureSetpoint(String value) async {
    await updateValue('S_TEMP_SETPT', value);
  }

  Future<void> updateHumiditySetpoint(String value) async {
    await updateValue('S_RH_SETPT', value);
  }

  Future<void> refreshData() async {
    await _fetchData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
