import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ESP32Provider with ChangeNotifier {
  // ESP32 connection - dynamic IP from SharedPreferences
  String _esp32IP = "192.168.4.1:8080"; // Default fallback
  Timer? _pollingTimer;
  bool _isConnected = false;

  // Getter for full ESP32 URL
  String get esp32BaseUrl => "http://$_esp32IP";

  // Getter for IP address
  String get esp32IP => _esp32IP;

  // Sensor data
  String _currentTemperature = "0.0";
  String _currentHumidity = "0.0";
  String _pressureValue = "0";
  bool _isPressurePositive = true;

  // Humidity setpoint
  String _humiditySetpoint = "50.0";

  // Temperature setpoint
  String _temperatureSetpoint = "25.0"; // Default value
  double _pendingTemperature = 25.0; // For gauge interaction
  DateTime? _temperatureSetpointGuardUntil;

  // ── BME688 Air Quality fields ────────────────────────────────────────────
  double _iaq = 0;
  double _staticIaq = 0;
  double _co2Eq = 0;
  double _vocEq = 0;
  double _gasPercent = 0;
  String _airQuality = "--";
  bool _airValid = false;

  // BME688 getters
  double get iaq => _iaq;
  double get staticIaq => _staticIaq;
  double get co2Eq => _co2Eq;
  double get vocEq => _vocEq;
  double get gasPercent => _gasPercent;
  String get airQuality => _airQuality;
  bool get airValid => _airValid;

  // ── VOC buffer for averaging (kept for compatibility) ────────────────────
  static const int _vocBufferSize = 10;
  final List<double> _vocEqBuffer = [];

  double get vocEqAvg => _vocEqBuffer.isEmpty
      ? _vocEq
      : _vocEqBuffer.reduce((a, b) => a + b) / _vocEqBuffer.length;

  // ── Setpoint guards ───────────────────────────────────────────────────────
  static const Duration _setpointGuardDuration = Duration(seconds: 15);
  DateTime? _humiditySetpointGuardUntil;

  bool get _isHumidityGuardActive =>
      _humiditySetpointGuardUntil != null &&
      DateTime.now().isBefore(_humiditySetpointGuardUntil!);

  bool get _isTemperatureGuardActive =>
      _temperatureSetpointGuardUntil != null &&
      DateTime.now().isBefore(_temperatureSetpointGuardUntil!);
  // ─────────────────────────────────────────────────────────────────────────

  // Light states
  List<bool> _lightStates = List.filled(10, false);

  // Sensor faults
  List<String> _sensorFaults = List.filled(10, "-1");

  // Backward compatibility control states - now mapped to lights 8, 9, 10
  bool _defumigation = false; // Light 8
  bool _systemPower = false; // Light 10
  bool _dayNightMode = false; // Light 9

  // ── Getters ───────────────────────────────────────────────────────────────
  bool get isConnected => _isConnected;
  String get currentTemperature => _currentTemperature;
  String get currentHumidity => _currentHumidity;
  String get pressureValue => _pressureValue;
  bool get isPressurePositive => _isPressurePositive;

  String get humiditySetpoint => _humiditySetpoint;
  double get humiditySetpointAsDouble =>
      double.tryParse(_humiditySetpoint) ?? 50.0;

  // Temperature getters
  String get temperatureSetpoint => _temperatureSetpoint;
  double get temperatureSetpointAsDouble =>
      double.tryParse(_temperatureSetpoint) ?? 25.0;
  double get pendingTemperature => _pendingTemperature;
  double get currentTemperatureAsDouble =>
      double.tryParse(_currentTemperature) ?? 0.0;

  List<String> get sensorFaults => List.unmodifiable(_sensorFaults);

  // Individual light getters
  bool get light1 => _lightStates[0];
  bool get light2 => _lightStates[1];
  bool get light3 => _lightStates[2];
  bool get light4 => _lightStates[3];
  bool get light5 => _lightStates[4];
  bool get light6 => _lightStates[5];
  bool get light7 => _lightStates[6];
  bool get light8 => _lightStates[7];
  bool get light9 => _lightStates[8];
  bool get light10 => _lightStates[9];

  // State getters (aliases)
  bool get light1State => _lightStates[0];
  bool get light2State => _lightStates[1];
  bool get light3State => _lightStates[2];
  bool get light4State => _lightStates[3];
  bool get light5State => _lightStates[4];
  bool get light6State => _lightStates[5];
  bool get light7State => _lightStates[6];
  bool get light8State => _lightStates[7];
  bool get light9State => _lightStates[8];
  bool get light10State => _lightStates[9];

  List<bool> get allLightStates => List.unmodifiable(_lightStates);

  bool getLightState(int index) {
    if (index >= 0 && index < _lightStates.length) return _lightStates[index];
    return false;
  }

  // Backward compatibility getters - correctly mapped to lights 8, 9, 10
  bool get defumigation => _lightStates[7]; // Light 8 (index 7)
  bool get systemPower => _lightStates[9]; // Light 10 (index 9)
  bool get dayNightMode => _lightStates[8]; // Light 9 (index 8)

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await loadSavedIpAddress();
    await _loadSavedSetpoints(); // restore setpoints before first poll
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

  /// Restore temperature and humidity setpoints saved locally.
  Future<void> _loadSavedSetpoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedTemp = prefs.getDouble("tempSetpoint");
      if (savedTemp != null) {
        _temperatureSetpoint = savedTemp.toStringAsFixed(1);
        _pendingTemperature = savedTemp;
        print("✅ Loaded saved temp setpoint: $_temperatureSetpoint°C");
      }

      final savedHumidity = prefs.getDouble("humiditySetpoint");
      if (savedHumidity != null) {
        _humiditySetpoint = savedHumidity.toStringAsFixed(1);
        print("✅ Loaded saved humidity setpoint: $_humiditySetpoint%");
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
      notifyListeners();

      stopPolling();
      startPolling();
    } catch (e) {
      print("❌ Error saving ESP32 IP: $e");
    }
  }

  // ── Temperature Methods ───────────────────────────────────────────────────

  void updatePendingTemperature(double value) {
    _pendingTemperature = value;
    notifyListeners();
    print("🌡️ Pending temperature updated to: ${value.toStringAsFixed(0)}°C");
  }

  Future<void> setTemperature(double temperature) async {
    print('🌡️ setTemperature called: ${temperature.toStringAsFixed(0)}°C');

    _temperatureSetpoint = temperature.toStringAsFixed(0);
    _pendingTemperature = temperature;
    _temperatureSetpointGuardUntil = DateTime.now().add(_setpointGuardDuration);
    print('🛡️ Temperature guard active until $_temperatureSetpointGuardUntil');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble("tempSetpoint", temperature);
      print("💾 Temp setpoint saved to SharedPreferences: ${temperature}°C");
    } catch (e) {
      print("❌ Failed to save temp setpoint: $e");
    }

    notifyListeners();

    final String temperatureValue = (temperature * 10).round().toString();
    print('📤 Sending S_TEMP_SETPT = $temperatureValue to ESP32');

    await _sendControl("S_TEMP_SETPT", temperatureValue);
  }

  Future<void> requestTemperatureStatus() async {
    print('🌡️ Requesting temperature status');
    await refreshData();
  }

  // ── Polling ───────────────────────────────────────────────────────────────
  void startPolling() {
    stopPolling();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkConnection();
      if (_isConnected) _fetchData();
    });
    _checkConnection();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$esp32BaseUrl/connection-test'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        if (!_isConnected) {
          _isConnected = true;
          print("✅ Connected to ESP32 at $_esp32IP");
          notifyListeners();
        }
      }
    } catch (e) {
      if (_isConnected) {
        _isConnected = false;
        print("❌ Disconnected from ESP32 at $_esp32IP: $e");
        notifyListeners();
      }
    }
  }

  Future<void> refreshData() async {
    await _checkConnection();
    if (_isConnected) await _fetchData();
  }

  Future<void> _fetchData() async {
    if (!_isConnected) return;

    try {
      print('📡 Trying /all-parameters...');
      final response = await http
          .get(Uri.parse('$esp32BaseUrl/all-parameters'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('sensor_faults')) {
          print('✅ Found sensor faults in /all-parameters');
          _parseAllParameters(data);
          return;
        }
      }
    } catch (e) {
      print("⚠️ /all-parameters failed: $e");
    }

    try {
      print('📡 Trying /data...');
      final response = await http
          .get(Uri.parse('$esp32BaseUrl/data'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String rawData = data['data'];
        if (rawData.contains('F_Sensor')) {
          print('✅ Found sensor faults in /data');
          _parseData(rawData);
          return;
        }
      }
    } catch (e) {
      print("⚠️ /data failed: $e");
    }

    try {
      print('📡 Trying /sensor-data...');
      final response = await http
          .get(Uri.parse('$esp32BaseUrl/sensor-data'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _parseSensorData(data);
      }
    } catch (e) {
      print("❌ All endpoints failed: $e");
      _isConnected = false;
      notifyListeners();
    }
  }

  // ── Parsers ───────────────────────────────────────────────────────────────

  void _parseAllParameters(Map<String, dynamic> data) {
    print('📊 Parsing ALL parameters');
    bool changed = false;

    try {
      if (data['temperature'] != null) {
        String newTemp = data['temperature'].toString();
        if (_currentTemperature != newTemp) {
          _currentTemperature = newTemp;
          changed = true;
        }
      }

      if (data['humidity'] != null) {
        String newHumidity = data['humidity'].toString();
        if (_currentHumidity != newHumidity) {
          _currentHumidity = newHumidity;
          changed = true;
        }
      }

      if (data['pressure2'] != null) {
        int pressureInt = int.tryParse(data['pressure2'].toString()) ?? 0;
        String newPressure = pressureInt.toString();
        if (_pressureValue != newPressure) {
          _pressureValue = newPressure;
          changed = true;
        }
      }

      if (data['pressure2_positive'] != null) {
        bool newPositive = data['pressure2_positive'] == true;
        if (_isPressurePositive != newPositive) {
          _isPressurePositive = newPositive;
          changed = true;
        }
      }

      if (data['sensor_faults'] != null && data['sensor_faults'] is List) {
        final faultList = data['sensor_faults'] as List;
        print('🔧 Raw sensor faults: $faultList');
        for (int i = 0; i < faultList.length && i < _sensorFaults.length; i++) {
          String newValue = faultList[i].toString();
          if (_sensorFaults[i] != newValue) {
            _sensorFaults[i] = newValue;
            changed = true;
          }
        }
      }

      // ── BME688 Air Quality data ──────────────────────────────────────────
      if (data['iaq'] != null) {
        double newIaq = (data['iaq'] as num).toDouble();
        if (_iaq != newIaq) {
          _iaq = newIaq;
          changed = true;
          print("🌬️ IAQ updated: $_iaq");
        }
      }

      if (data['static_iaq'] != null) {
        double newStaticIaq = (data['static_iaq'] as num).toDouble();
        if (_staticIaq != newStaticIaq) {
          _staticIaq = newStaticIaq;
          changed = true;
        }
      }

      if (data['co2_eq'] != null) {
        double newCo2Eq = (data['co2_eq'] as num).toDouble();
        if (_co2Eq != newCo2Eq) {
          _co2Eq = newCo2Eq;
          changed = true;
        }
      }

      if (data['voc_eq'] != null) {
        double newVocEq = (data['voc_eq'] as num).toDouble();
        if (_vocEq != newVocEq) {
          _vocEq = newVocEq;
          if (_airValid) {
            _vocEqBuffer.add(newVocEq);
            if (_vocEqBuffer.length > _vocBufferSize) {
              _vocEqBuffer.removeAt(0);
            }
          }
          changed = true;
          print(
            "📟 VOC eq=$newVocEq ppm | buffer=${_vocEqBuffer.length} | avg=${vocEqAvg.toStringAsFixed(2)}",
          );
        }
      }

      if (data['gas_percent'] != null) {
        double newGasPercent = (data['gas_percent'] as num).toDouble();
        if (_gasPercent != newGasPercent) {
          _gasPercent = newGasPercent;
          changed = true;
        }
      }

      if (data['air_quality'] != null) {
        String newAirQuality = data['air_quality'].toString();
        if (_airQuality != newAirQuality) {
          _airQuality = newAirQuality;
          changed = true;
        }
      }

      if (data['air_valid'] != null) {
        bool newValid = data['air_valid'] == true;
        if (_airValid != newValid) {
          _airValid = newValid;
          if (newValid && _vocEqBuffer.isEmpty) {
            print("🌬️ BME688 air_valid = true, buffer ready");
          }
          changed = true;
        }
      }
      // ─────────────────────────────────────────────────────────────────────

      // ── Humidity setpoint — GUARDED ──────────────────────────────────────
      if (data['humidity_setpoint'] != null) {
        if (_isHumidityGuardActive) {
          print(
            '🛡️ Humidity guard active — keeping user value $_humiditySetpoint, '
            'ignoring ESP32 value ${data['humidity_setpoint']}',
          );
        } else {
          String newSetpoint = data['humidity_setpoint'].toString();
          if (_humiditySetpoint != newSetpoint) {
            _humiditySetpoint = newSetpoint;
            changed = true;
            print(
              '💧 Humidity setpoint updated from ESP32: $_humiditySetpoint',
            );
          }
        }
      }

      // ── Temperature setpoint — GUARDED ───────────────────────────────────
      if (data['temperature_setpoint'] != null) {
        if (_isTemperatureGuardActive) {
          print(
            '🛡️ Temperature guard active — keeping user value $_temperatureSetpoint, '
            'ignoring ESP32 value ${data['temperature_setpoint']}',
          );
        } else {
          String newSetpoint = data['temperature_setpoint'].toString();
          if (_temperatureSetpoint != newSetpoint) {
            _temperatureSetpoint = newSetpoint;
            _pendingTemperature = double.tryParse(newSetpoint) ?? 25.0;
            changed = true;
            print(
              '🌡️ Temperature setpoint updated from ESP32: $_temperatureSetpoint',
            );
          }
        }
      }

      if (data['light_status'] != null && data['light_status'] is List) {
        final lightList = data['light_status'] as List;
        for (int i = 0; i < lightList.length && i < _lightStates.length; i++) {
          bool newState = lightList[i] == 1 || lightList[i] == "1";
          if (_lightStates[i] != newState) {
            _lightStates[i] = newState;
            if (i == 7) _defumigation = newState;
            if (i == 8) _dayNightMode = newState;
            if (i == 9) _systemPower = newState;
            changed = true;
          }
        }
      }

      if (changed) {
        notifyListeners();
        print('✅ Data changed, listeners notified');
      }
    } catch (e) {
      print("❌ Error parsing all parameters: $e");
    }
  }

  void _parseSensorData(Map<String, dynamic> data) {
    print('📊 Parsing sensor data');
    try {
      if (data['temperature'] != null) {
        _currentTemperature = data['temperature'].toString();
      }
      if (data['humidity'] != null) {
        _currentHumidity = data['humidity'].toString();
      }

      if (data['pressure'] != null) {
        final pressureDouble =
            double.tryParse(data['pressure'].toString()) ?? 0.0;
        int pressureInt = (pressureDouble * 100).toInt();
        _pressureValue = pressureInt.toString();
      }

      if (data['pressure_positive'] != null) {
        _isPressurePositive =
            data['pressure_positive'] == true ||
            data['pressure_positive'] == "1" ||
            data['pressure_positive'] == 1;
      }

      // ── BME688 Air Quality data ──────────────────────────────────────────
      _iaq = (data['iaq'] ?? 0).toDouble();
      _staticIaq = (data['static_iaq'] ?? 0).toDouble();
      _co2Eq = (data['co2_eq'] ?? 0).toDouble();
      _vocEq = (data['voc_eq'] ?? 0).toDouble();
      _gasPercent = (data['gas_percent'] ?? 0).toDouble();
      _airQuality = data['air_quality'] ?? "--";
      _airValid = data['air_valid'] ?? false;

      if (_airValid && _vocEq > 0) {
        _vocEqBuffer.add(_vocEq);
        if (_vocEqBuffer.length > _vocBufferSize) {
          _vocEqBuffer.removeAt(0);
        }
      }
      // ─────────────────────────────────────────────────────────────────────

      // ── Humidity setpoint — GUARDED ──────────────────────────────────────
      if (data['humidity_setpoint'] != null) {
        if (_isHumidityGuardActive) {
          print(
            '🛡️ Humidity guard active — ignoring poll value ${data['humidity_setpoint']}',
          );
        } else {
          _humiditySetpoint = data['humidity_setpoint'].toString();
          print('💧 Humidity setpoint from ESP32: $_humiditySetpoint');
        }
      }

      // ── Temperature setpoint — GUARDED ───────────────────────────────────
      if (data['temperature_setpoint'] != null) {
        if (_isTemperatureGuardActive) {
          print(
            '🛡️ Temperature guard active — ignoring poll value ${data['temperature_setpoint']}',
          );
        } else {
          _temperatureSetpoint = data['temperature_setpoint'].toString();
          _pendingTemperature = double.tryParse(_temperatureSetpoint) ?? 25.0;
          print('🌡️ Temperature setpoint from ESP32: $_temperatureSetpoint');
        }
      }

      for (int i = 1; i <= 10; i++) {
        String key1 = 'F_Sensor_${i}_FAULT_BIT';
        String key2 = 'sensor_fault_$i';
        if (data.containsKey(key1)) {
          _sensorFaults[i - 1] = data[key1].toString();
        } else if (data.containsKey(key2)) {
          _sensorFaults[i - 1] = data[key2].toString();
        }
      }

      if (data['light_status'] != null && data['light_status'] is List) {
        final lightList = data['light_status'] as List;
        for (int i = 0; i < lightList.length && i < _lightStates.length; i++) {
          _lightStates[i] = lightList[i] == 1 || lightList[i] == "1";
          if (i == 7) _defumigation = _lightStates[i];
          if (i == 8) _dayNightMode = _lightStates[i];
          if (i == 9) _systemPower = _lightStates[i];
        }
      }

      notifyListeners();
    } catch (e) {
      print("❌ Error parsing sensor data: $e");
    }
  }

  void _parseData(String data) {
    try {
      print('🔄 Parsing legacy data');

      final tempMatch = RegExp(r'C_OT_TEMP:(\d+)').firstMatch(data);
      if (tempMatch != null) {
        _currentTemperature =
            ((int.tryParse(tempMatch.group(1) ?? '0') ?? 0) / 10.0)
                .toStringAsFixed(1);
      }

      final humidityMatch = RegExp(r'C_RH:(\d+)').firstMatch(data);
      if (humidityMatch != null) {
        _currentHumidity =
            ((int.tryParse(humidityMatch.group(1) ?? '0') ?? 0) / 10.0)
                .toStringAsFixed(1);
      }

      final pressureMatch = RegExp(r'C_PRESSURE_2:(\d+)').firstMatch(data);
      final pressureSignMatch = RegExp(
        r'C_PRESSURE_2_SIGN_BIT:(\d+)',
      ).firstMatch(data);
      if (pressureMatch != null) {
        final pressureInt = int.tryParse(pressureMatch.group(1) ?? '0') ?? 0;
        _isPressurePositive = pressureSignMatch?.group(1) == '0';
      }

      // ── Humidity setpoint — GUARDED ──────────────────────────────────────
      final humiditySetpointMatch = RegExp(
        r'S_RH_SETPT:(\d+)',
      ).firstMatch(data);
      if (humiditySetpointMatch != null) {
        if (_isHumidityGuardActive) {
          print('🛡️ Humidity guard active — ignoring legacy poll setpoint');
        } else {
          _humiditySetpoint =
              ((int.tryParse(humiditySetpointMatch.group(1) ?? '0') ?? 0) /
                      10.0)
                  .toStringAsFixed(1);
          print('💧 Humidity setpoint from legacy: $_humiditySetpoint');
        }
      }

      // ── Temperature setpoint — GUARDED ───────────────────────────────────
      final tempSetpointMatch = RegExp(r'S_TEMP_SETPT:(\d+)').firstMatch(data);
      if (tempSetpointMatch != null) {
        if (_isTemperatureGuardActive) {
          print('🛡️ Temperature guard active — ignoring legacy poll setpoint');
        } else {
          _temperatureSetpoint =
              ((int.tryParse(tempSetpointMatch.group(1) ?? '0') ?? 0) / 10.0)
                  .toStringAsFixed(1);
          _pendingTemperature = double.tryParse(_temperatureSetpoint) ?? 25.0;
          print('🌡️ Temperature setpoint from legacy: $_temperatureSetpoint');
        }
      }

      for (int i = 1; i <= 10; i++) {
        final faultMatch = RegExp(
          r'F_Sensor_' + i.toString() + r'_FAULT_BIT:(\d)',
        ).firstMatch(data);
        if (faultMatch != null) {
          _sensorFaults[i - 1] = faultMatch.group(1) ?? "-1";
        }
      }

      for (int i = 1; i <= 10; i++) {
        final lightMatch = RegExp(
          r'S_Light_' + i.toString() + r'_ON_OFF:(\d)',
        ).firstMatch(data);
        if (lightMatch != null) {
          _lightStates[i - 1] = lightMatch.group(1) == "1";
          if (i == 8) _defumigation = _lightStates[7];
          if (i == 9) _dayNightMode = _lightStates[8];
          if (i == 10) _systemPower = _lightStates[9];
        }
      }

      notifyListeners();
    } catch (e) {
      print("❌ Error parsing legacy data: $e");
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Future<void> sendControl(String key, String value) async {
    await _sendControl(key, value);
  }

  Future<void> _sendControl(String key, String value) async {
    print('🚀 Sending control: $key = $value');
    try {
      final response = await http
          .post(Uri.parse('$esp32BaseUrl/control'), body: {key: value})
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        print('✅ Control $key = $value confirmed by ESP32');

        if (key == "S_RH_SETPT") {
          print(
            '🛡️ Humidity guard remains active until $_humiditySetpointGuardUntil',
          );
        } else if (key == "S_TEMP_SETPT") {
          print(
            '🛡️ Temperature guard remains active until $_temperatureSetpointGuardUntil',
          );
        } else if (key.startsWith("S_Light_") && key.endsWith("_ON_OFF")) {
          final lightNumber =
              int.tryParse(key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          if (lightNumber >= 1 && lightNumber <= 10) {
            _lightStates[lightNumber - 1] = value == "1";
            if (lightNumber == 8) _defumigation = value == "1";
            if (lightNumber == 9) _dayNightMode = value == "1";
            if (lightNumber == 10) _systemPower = value == "1";
            notifyListeners();
          }
        }
      } else {
        print('❌ Control failed: ${response.statusCode}');
        throw Exception('Control failed: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Failed to send control: $e");
      rethrow;
    }
  }

  Future<void> _sendMultipleControls(Map<String, String> controls) async {
    print('🚀 Sending multiple controls: $controls');
    try {
      final response = await http
          .post(Uri.parse('$esp32BaseUrl/control'), body: controls)
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        print('✅ Multiple controls confirmed');
        controls.forEach((key, value) {
          if (key.startsWith("S_Light_") && key.endsWith("_ON_OFF")) {
            final n = int.tryParse(key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            if (n >= 1 && n <= 10) {
              _lightStates[n - 1] = value == "1";
              if (n == 8) _defumigation = value == "1";
              if (n == 9) _dayNightMode = value == "1";
              if (n == 10) _systemPower = value == "1";
            }
          }
        });
        notifyListeners();
      } else {
        print('❌ Multiple controls failed: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Multiple controls error: $e");
    }
  }

  // ── Setpoint setters ──────────────────────────────────────────────────────

  Future<void> setHumiditySetpoint(double humidity) async {
    print('💧 setHumiditySetpoint called: $humidity%');

    _humiditySetpoint = humidity.toStringAsFixed(1);
    _humiditySetpointGuardUntil = DateTime.now().add(_setpointGuardDuration);
    print('🛡️ Humidity guard active until $_humiditySetpointGuardUntil');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble("humiditySetpoint", humidity);
      print("💾 Humidity setpoint saved to SharedPreferences: ${humidity}%");
    } catch (e) {
      print("❌ Failed to save humidity setpoint: $e");
    }

    notifyListeners();

    final String humidityValue = (humidity * 10).round().toString().padLeft(
      3,
      '0',
    );
    print('📤 Sending S_RH_SETPT = $humidityValue to ESP32');

    await _sendControl("S_RH_SETPT", humidityValue);
  }

  // ── Light controls ────────────────────────────────────────────────────────

  Future<void> toggleLight(int lightNumber, bool value) async {
    if (lightNumber < 1 || lightNumber > 10) {
      print('❌ Invalid light number: $lightNumber');
      return;
    }
    _lightStates[lightNumber - 1] = value;
    if (lightNumber == 8) _defumigation = value;
    if (lightNumber == 9) _dayNightMode = value;
    if (lightNumber == 10) _systemPower = value;
    notifyListeners();
    await _sendControl("S_Light_${lightNumber}_ON_OFF", value ? "1" : "0");
  }

  Future<void> toggleMultipleLights(Map<int, bool> lightStates) async {
    if (lightStates.isEmpty) return;
    Map<String, String> controls = {};
    lightStates.forEach((lightNumber, value) {
      if (lightNumber >= 1 && lightNumber <= 10) {
        _lightStates[lightNumber - 1] = value;
        if (lightNumber == 8) _defumigation = value;
        if (lightNumber == 9) _dayNightMode = value;
        if (lightNumber == 10) _systemPower = value;
        controls["S_Light_${lightNumber}_ON_OFF"] = value ? "1" : "0";
      }
    });
    notifyListeners();
    if (controls.isNotEmpty) await _sendMultipleControls(controls);
  }

  // ✅ Only toggles lights 1-4, NOT system controls (8, 9, 10)
  Future<void> toggleAllLights(bool value) async {
    Map<String, String> controls = {};
    for (int i = 1; i <= 4; i++) {
      _lightStates[i - 1] = value;
      controls["S_Light_${i}_ON_OFF"] = value ? "1" : "0";
    }
    notifyListeners();
    await _sendMultipleControls(controls);
  }

  Future<void> setLightPattern(List<bool> pattern) async {
    if (pattern.length > 10) return;
    Map<String, String> controls = {};
    for (int i = 0; i < pattern.length && i < 10; i++) {
      _lightStates[i] = pattern[i];
      controls["S_Light_${i + 1}_ON_OFF"] = pattern[i] ? "1" : "0";
    }
    if (pattern.length > 7) _defumigation = pattern[7];
    if (pattern.length > 8) _dayNightMode = pattern[8];
    if (pattern.length > 9) _systemPower = pattern[9];
    notifyListeners();
    await _sendMultipleControls(controls);
  }

  // Backward compatibility toggle methods
  Future<void> toggleDefumigation(bool value) async => toggleLight(8, value);
  Future<void> toggleSystemPower(bool value) async => toggleLight(10, value);
  Future<void> toggleDayNightMode(bool value) async => toggleLight(9, value);

  // ── Utilities ─────────────────────────────────────────────────────────────

  Future<void> _fetchLegacyData() async {
    try {
      final response = await http
          .get(Uri.parse('$esp32BaseUrl/data'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _parseData(data['data']);
      }
    } catch (e) {
      print("❌ Failed to fetch legacy data: $e");
      _isConnected = false;
      notifyListeners();
    }
  }

  String getFormattedPressure() {
    return _pressureValue;
  }

  Color getPressureColor() {
    return _isPressurePositive ? Colors.white : Colors.white;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
