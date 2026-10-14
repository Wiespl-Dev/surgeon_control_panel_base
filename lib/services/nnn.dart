// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// /// Polls the ESP32 standalone controller's MGPS gas zones, relay-driven
// /// light control, and differential pressure reading.
// ///
// /// Replaces VOCProvider — the firmware has no BME688 VOC/IAQ endpoint;
// /// it exposes /api/gas, /api/lights, and /api/pressure instead. This
// /// provider talks to those.
// ///
// /// NOTE: this runs its own timer, so if this app is also polling the
// /// same controller from another provider (ESP32Provider /
// /// GlobalUsbProvider), this is a second concurrent poller hitting the
// /// same web server. Kept at a longer, offset interval on purpose — see
// /// the old VOCProvider note about dropped writes if two pollers hit the
// /// same endpoints too aggressively. If you see setpoint/relay snap-back
// /// again, merge this into the single existing poll loop instead.
// class OTPanelProvider extends ChangeNotifier {
//   // Changed to use "vocIp" key as per the login screen
//   static const String _ipPrefKey = 'vocIp';
//   static const String _defaultIp = '192.168.4.1'; // Waveshare WiFi AP gateway
//   static const int _port = 80; // firmware's WebServer runs on :80, not :8080
//   static const Duration _pollInterval = Duration(seconds: 3);
//   static const Duration _requestTimeout = Duration(seconds: 4);

//   String esp32IP = _defaultIp;

//   // ── Light control (relays 1-8) ──────────────────────────────────
//   final List<bool> lightStates = List<bool>.filled(8, false);

//   // ── MGPS gas zones (1-8) ─────────────────────────────────────────
//   final List<bool> gasZoneFull = List<bool>.filled(8, false);

//   // ── Differential pressure ────────────────────────────────────────
//   double pressurePa = 0.0;
//   double pressureRangePa = 62.5;

//   bool isConnected = false;

//   Timer? _pollTimer;
//   bool _isDisposed = false;

//   // Counts in-flight light writes. While > 0, a poll response is not
//   // applied to lightStates — otherwise a GET that was already in flight
//   // when the user tapped a light can overwrite their tap with stale data.
//   // This is the same class of bug as the panel's earlier setpoint
//   // snap-back / stale-echo issue, so it's guarded the same way here.
//   int _pendingLightWrites = 0;

//   Future<void> initialize({String? ipOverride}) async {
//     if (ipOverride != null && ipOverride.isNotEmpty) {
//       esp32IP = _stripPort(ipOverride);
//     } else {
//       final prefs = await SharedPreferences.getInstance();
//       esp32IP = _stripPort(prefs.getString(_ipPrefKey) ?? _defaultIp);
//     }
//     print('🔍 OTPanelProvider connecting to: http://$esp32IP:$_port');
//     await _fetchStatus();
//     _startPolling();
//   }

//   /// Normalize down to a bare host — avoids building
//   /// "192.168.4.1:80:80" if the saved pref already has a scheme or port.
//   String _stripPort(String raw) {
//     var host = raw.trim();
//     host = host.replaceFirst(RegExp(r'^https?://'), '');
//     final colonIndex = host.indexOf(':');
//     if (colonIndex != -1) {
//       host = host.substring(0, colonIndex);
//     }
//     final slashIndex = host.indexOf('/');
//     if (slashIndex != -1) {
//       host = host.substring(0, slashIndex);
//     }
//     return host;
//   }

//   void _startPolling() {
//     _pollTimer?.cancel();
//     _pollTimer = Timer.periodic(_pollInterval, (_) => _fetchStatus());
//   }

//   Uri _uri(String path) => Uri.parse('http://$esp32IP:$_port$path');

//   Future<void> _fetchStatus() async {
//     bool anySuccess = false;
    
//     try {
//       // Try to fetch lights
//       try {
//         final lightsResp = await http.get(_uri('/api/lights')).timeout(_requestTimeout);
//         if (lightsResp.statusCode == 200) {
//           _applyLights(jsonDecode(lightsResp.body) as Map<String, dynamic>);
//           anySuccess = true;
//         }
//       } catch (e) {
//         debugPrint('OTPanelProvider: /api/lights failed: $e');
//       }

//       // Try to fetch pressure
//       try {
//         final pressureResp = await http.get(_uri('/api/pressure')).timeout(_requestTimeout);
//         if (pressureResp.statusCode == 200) {
//           _applyPressure(jsonDecode(pressureResp.body) as Map<String, dynamic>);
//           anySuccess = true;
//         }
//       } catch (e) {
//         debugPrint('OTPanelProvider: /api/pressure failed: $e');
//       }

//       // Try to fetch gas
//       try {
//         final gasResp = await http.get(_uri('/api/gas')).timeout(_requestTimeout);
//         if (gasResp.statusCode == 200) {
//           _applyGas(jsonDecode(gasResp.body) as Map<String, dynamic>);
//           anySuccess = true;
//         }
//       } catch (e) {
//         debugPrint('OTPanelProvider: /api/gas failed: $e');
//       }

//       // Update connection status based on ANY endpoint success
//       if (anySuccess) {
//         if (!isConnected) {
//           isConnected = true;
//           debugPrint('✅ OTPanelProvider connected to $esp32IP');
//         }
//       } else {
//         if (isConnected) {
//           isConnected = false;
//           debugPrint('❌ OTPanelProvider disconnected from $esp32IP');
//         }
//       }

//     } catch (e) {
//       isConnected = false;
//       debugPrint('OTPanelProvider: fetch failed: $esp32IP ($e)');
//     }
    
//     if (!_isDisposed) notifyListeners();
//   }

//   void _applyLights(Map<String, dynamic> data) {
//     if (_pendingLightWrites > 0) return; // see note on the field above
//     for (var i = 0; i < 8; i++) {
//       lightStates[i] = data['light${i + 1}'] == true;
//     }
//   }

//   void _applyGas(Map<String, dynamic> data) {
//     final zones = data['gas'];
//     if (zones is! List) return;
//     for (final z in zones) {
//       if (z is! Map) continue;
//       final id = (z['id'] as num?)?.toInt();
//       if (id == null || id < 1 || id > 8) continue;
//       gasZoneFull[id - 1] = z['full'] == true;
//     }
//   }

//   void _applyPressure(Map<String, dynamic> data) {
//     pressurePa = _toDouble(data['pressure_pa']);
//     pressureRangePa = _toDouble(data['range_pa']);
//   }

//   double _toDouble(dynamic v) {
//     if (v == null) return 0.0;
//     if (v is num) return v.toDouble();
//     return double.tryParse(v.toString()) ?? 0.0;
//   }

//   // ── Light control ────────────────────────────────────────────────

//   /// Sets a single relay (1-8). Updates the UI immediately (optimistic),
//   /// then rolls back if the write actually failed — e.g. the firmware
//   /// returns 403 for relays 7/8 while fumigation is running. Returns
//   /// true/false so the caller can show an error toast on failure.
//   Future<bool> setLight(int id, bool state) async {
//     if (id < 1 || id > 8) return false;
//     final previous = lightStates[id - 1];
//     _pendingLightWrites++;
//     lightStates[id - 1] = state;
//     notifyListeners();
//     try {
//       final resp = await http
//           .post(
//             _uri('/api/light'),
//             headers: {'Content-Type': 'application/json'},
//             body: jsonEncode({'id': id, 'state': state}),
//           )
//           .timeout(_requestTimeout);
//       final ok = resp.statusCode == 200;
//       if (!ok) lightStates[id - 1] = previous;
//       return ok;
//     } catch (e) {
//       lightStates[id - 1] = previous;
//       debugPrint('OTPanelProvider: setLight($id) failed: $e');
//       return false;
//     } finally {
//       _pendingLightWrites--;
//       if (!_isDisposed) notifyListeners();
//     }
//   }

//   Future<bool> toggleLight(int id) async {
//     if (id < 1 || id > 8) return false;
//     return setLight(id, !lightStates[id - 1]);
//   }

//   /// All lights on/off. The firmware itself refuses this during an
//   /// active fumigation countdown/run (relays 7/8 stay untouched, and a
//   /// plain "all" request during those states is rejected outright), so
//   /// the rollback path here mainly covers network failures.
//   Future<bool> setAllLights(bool state) async {
//     final previous = List<bool>.from(lightStates);
//     _pendingLightWrites++;
//     for (var i = 0; i < 8; i++) {
//       lightStates[i] = state;
//     }
//     notifyListeners();
//     try {
//       final resp = await http
//           .post(
//             _uri('/api/lights/all'),
//             headers: {'Content-Type': 'application/json'},
//             body: jsonEncode({'state': state}),
//           )
//           .timeout(_requestTimeout);
//       final ok = resp.statusCode == 200;
//       if (!ok) lightStates.setAll(0, previous);
//       return ok;
//     } catch (e) {
//       lightStates.setAll(0, previous);
//       debugPrint('OTPanelProvider: setAllLights failed: $e');
//       return false;
//     } finally {
//       _pendingLightWrites--;
//       if (!_isDisposed) notifyListeners();
//     }
//   }

//   /// Call this from Home's dispose(), mirroring the old
//   /// VOCProvider.stopPolling() / esp32Provider.stopPolling().
//   void stopPolling() {
//     _pollTimer?.cancel();
//     _pollTimer = null;
//   }

//   @override
//   void dispose() {
//     _isDisposed = true;
//     _pollTimer?.cancel();
//     super.dispose();
//   }
// }
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Talks to two devices:
///
/// 1. The Waveshare ESP32-S3 controller (Waveshare_ESP32S3_Master v7.2 firmware) at
///    "vocIp":80 (default 192.168.4.1, its WiFi AP gateway — the firmware
///    serves Android only there) — relays, pressure, gas, night mode,
///    fumigation:
///    - GET  /api/status and /api/pressure each poll; /api/lights only
///      after a night-mode change
///    - /api/status — `local` (night_mode, relay_state, gas_state bitmasks)
///      and `second_esp` (temp/RH +
///      setpoints pushed to it by a slave ESP32, real units)
///    - POST /api/light, /api/lights/all, /api/night
///    - POST /api/temperature/setpoint, /api/humidity/setpoint {"value": v}
///      (forwarded to the slave; 503 if it is offline)
///
/// 2. The "espwifipp" ESP32 at "espIp":8080, which bridges the AHU
///    controller over RS485:
///    - GET  /all-parameters — temp/RH + setpoints (strings; setpoints ×10,
///      e.g. "240" = 24.0 °C), light_status[] and sensor_faults[]
///    - POST /control — form-encoded writes (S_TEMP_SETPT, S_RH_SETPT,
///      S_Light_N_ON_OFF)
///
/// Source selection, so the app works with either wiring:
/// - Temp/RH: the espwifipp board directly if it answers, otherwise the
///   Waveshare's `second_esp` data.
/// - Lights/MGPS: the Waveshare if it answers, otherwise the espwifipp board
///   (single-board install).
class OTPanelProvider extends ChangeNotifier {
  // Waveshare controller — uses "vocIp" key from SharedPreferences
  static const String _ipPrefKey = 'vocIp';
  static const String _defaultIp = '192.168.4.1'; // Waveshare WiFi AP gateway
  static const int _port = 80;

  // Temperature/humidity ESP32 — uses "espIp" key from SharedPreferences
  static const String _tempIpPrefKey = 'espIp';
  static const String _defaultTempIp = '192.168.4.1';
  static const int _tempPort = 8080;

  static const Duration _pollInterval = Duration(seconds: 3);
  // The espwifipp board can't answer HTTP while it is reading an RS485
  // packet (readStringUntil at 9600 baud, ~1 s each), so give it headroom.
  static const Duration _requestTimeout = Duration(seconds: 6);

  // A single slow/missed poll is normal on these boards. Only report a
  // device offline after this many consecutive failed polls (~10-20 s),
  // otherwise the UI flickers between Connected and Disconnected.
  static const int _offlineAfterFailures = 3;
  int _waveshareFailures = 0;
  int _tempEspFailures = 0;
  int _wsSecondEspOfflinePolls = 0;
  // Poll cycles between retries of an offline "espIp":8080 board (~30 s).
  static const int _offlineRetryEvery = 10;

  // After a /control write the ESP32 relays it over RS485, and the AHU's
  // next packet can still echo the old setpoint. Hold the locally written
  // value for this long before trusting /sensor-data again.
  static const Duration _setpointGuard = Duration(seconds: 15);

  String esp32IP = _defaultIp;
  String tempEspIP = _defaultTempIp;

  // ── Light control (relays 1-10) ─────────────────────────────────
  // Relays 1-8 exist on both boards; 9 (defumigation) and 10 (system
  // on/off) only on the espwifipp board's AHU controller
  // (S_Light_9/10_ON_OFF).
  static const int _waveshareRelayCount = 8;
  final List<bool> lightStates = List<bool>.filled(10, false);

  // ── MGPS gas zones (1-8) ─────────────────────────────────────────
  final List<bool> gasZoneFull = List<bool>.filled(8, false);

  // ── Differential pressure ────────────────────────────────────────
  double pressurePa = 0.0;
  double pressureRangePa = 62.5;

  // ── Second ESP32: Temperature / Humidity ─────────────────────────
  /// Temp/RH data is available — either directly from the espwifipp board
  /// or relayed by the Waveshare from its slave ESP32.
  bool secondEspOnline = false;

  // The espwifipp board answers directly at "espIp":8080 (debounced).
  bool _tempEspDirectOnline = false;

  // No direct board, but the Waveshare reports its slave ESP32 online and
  // relays its temp/RH; setpoints then go through the Waveshare.
  bool _tempViaWaveshare = false;

  // Latest /api/status `second_esp` object from this poll cycle.
  Map<String, dynamic>? _lastWaveshareSecondEsp;

  /// That ESP32 has received valid RS485 data from the AHU controller, i.e.
  /// the readings below are real rather than its "0.0" defaults.
  bool secondEspDataReceived = false;
  double temperature = 0.0;
  double humidity = 0.0;
  double temperatureSetpoint = 0.0;
  double humiditySetpoint = 0.0;
  DateTime? _tempSetpointGuardUntil;
  DateTime? _humSetpointGuardUntil;

  // ── Controller state (from /api/status "local") ──────────────────
  bool nightModeActive = false;

  /// The Waveshare controller answered its last poll.
  bool waveshareOnline = false;

  /// At least one device is reachable. Lights and MGPS come from the
  /// Waveshare when it is online, otherwise from the temp/RH ESP32
  /// (which also drives lights and reads gas sensors over RS485).
  bool isConnected = false;

  Timer? _pollTimer;
  bool _isDisposed = false;
  bool _isFetching = false;
  int _pendingLightWrites = 0;

  // The ESP32 relays light writes over RS485 and the AHU's next packet can
  // still echo the old state; hold locally written light states this long.
  final List<DateTime?> _espLightGuardUntil = List<DateTime?>.filled(10, null);

  // Latest /all-parameters body from this poll cycle (lights/MGPS source).
  Map<String, dynamic>? _lastEspIo;

  /// Lights/MGPS are served by the temp/RH ESP32 (no Waveshare present).
  bool get _espIsIoSource => !waveshareOnline && _tempEspDirectOnline;

  Future<void> initialize({String? ipOverride}) async {
    final prefs = await SharedPreferences.getInstance();
    if (ipOverride != null && ipOverride.isNotEmpty) {
      esp32IP = _stripPort(ipOverride);
    } else {
      esp32IP = _stripPort(prefs.getString(_ipPrefKey) ?? _defaultIp);
    }
    final savedTempIp = prefs.getString(_tempIpPrefKey);
    tempEspIP = _stripPort(
      savedTempIp == null || savedTempIp.isEmpty ? _defaultTempIp : savedTempIp,
    );
    print('🔍 OTPanelProvider connecting to: http://$esp32IP:$_port '
        '(temp/RH: http://$tempEspIP:$_tempPort)');
    await _fetchStatus();
    _startPolling();
  }

  /// Normalize down to a bare host — avoids building
  /// "192.168.4.1:80:80" if the saved pref already has a scheme or port.
  String _stripPort(String raw) {
    var host = raw.trim();
    host = host.replaceFirst(RegExp(r'^https?://'), '');
    final colonIndex = host.indexOf(':');
    if (colonIndex != -1) {
      host = host.substring(0, colonIndex);
    }
    final slashIndex = host.indexOf('/');
    if (slashIndex != -1) {
      host = host.substring(0, slashIndex);
    }
    return host;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _fetchStatus());
  }

  Uri _uri(String path) => Uri.parse('http://$esp32IP:$_port$path');
  Uri _tempUri(String path) => Uri.parse('http://$tempEspIP:$_tempPort$path');

  Future<void> _fetchStatus() async {
    // Each request can take up to _requestTimeout when a device is
    // unreachable, so don't let timer ticks stack up behind a slow cycle.
    if (_isFetching) return;
    _isFetching = true;

    try {
      // The two devices are independent — poll them in parallel so one
      // being offline doesn't delay the other.
      await Future.wait([_pollController(), _pollTempEsp()]);
    } finally {
      _isFetching = false;
    }

    final espIo = _lastEspIo;
    _lastEspIo = null;
    if (espIo != null) {
      if (_espIsIoSource) {
        _applyEspLights(espIo['light_status']);
        _applyEspSensorFaults(espIo['sensor_faults']);
        _applyEspPressure(espIo);
      } else {
        // Waveshare owns relays 1-8; 9 and 10 still come from the ESP32.
        _applyEspLights(espIo['light_status'], from: _waveshareRelayCount);
      }
    }

    // Temp/RH: the Waveshare is the gateway for the temp/RH ESP32 (v7.2
    // firmware), so its `second_esp` data wins whenever that node is
    // registered — the same data the Waveshare web page shows. The direct
    // espwifipp board is only a fallback. If this cycle's Waveshare poll was
    // missed (but it isn't offline yet), keep the previous choice.
    final viaWs = _lastWaveshareSecondEsp;
    _lastWaveshareSecondEsp = null;
    if (!waveshareOnline) {
      _tempViaWaveshare = false;
    } else if (viaWs != null) {
      final registered = (viaWs['device_id'] ?? '').toString().isNotEmpty;
      if (registered) {
        _applyWaveshareSecondEsp(viaWs);
        // The firmware flags the node offline after 6 s without a push, so
        // `online` can flicker; only drop it after several offline reports.
        _wsSecondEspOfflinePolls =
            viaWs['online'] == true ? 0 : _wsSecondEspOfflinePolls + 1;
        _tempViaWaveshare = _wsSecondEspOfflinePolls < _offlineAfterFailures;
      } else {
        _tempViaWaveshare = false;
      }
    }

    secondEspOnline = _tempEspDirectOnline || _tempViaWaveshare;
    isConnected = waveshareOnline || secondEspOnline;
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _pollController() async {
    // The Waveshare's web server answers one request at a time, so keep the
    // poll small: /api/status carries relays, gas, night mode and the temp/RH
    // node in one reply. Pressure needs /api/pressure — the firmware only
    // takes a fresh reading there.
    final reachable = await _get(_uri('/api/status'), _applyStatus);
    if (reachable) {
      await _get(_uri('/api/pressure'), _applyPressure);
    }

    _waveshareFailures = reachable ? 0 : _waveshareFailures + 1;
    final online = reachable ||
        (waveshareOnline && _waveshareFailures < _offlineAfterFailures);
    if (online != waveshareOnline) {
      waveshareOnline = online;
      debugPrint(online
          ? '✅ Waveshare connected at $esp32IP:$_port'
          : '❌ Waveshare not reachable at $esp32IP:$_port');
    }
  }

  Future<void> _pollTempEsp() async {
    // With the v7.2 Waveshare there is usually no board at "espIp":8080.
    // While it's offline, only retry every few cycles instead of every poll.
    if (!_tempEspDirectOnline &&
        _tempEspFailures >= _offlineAfterFailures &&
        _tempEspFailures++ % _offlineRetryEvery != 0) {
      return;
    }
    // /all-parameters is /sensor-data plus light_status[] and
    // sensor_faults[], which are needed when there is no Waveshare.
    final reachable = await _get(_tempUri('/all-parameters'), _applySensorData);
    _tempEspFailures = reachable ? 0 : _tempEspFailures + 1;
    final online = reachable ||
        (_tempEspDirectOnline && _tempEspFailures < _offlineAfterFailures);
    if (online != _tempEspDirectOnline) {
      _tempEspDirectOnline = online;
      debugPrint(online
          ? '✅ Temp/RH ESP32 connected at $tempEspIP:$_tempPort'
          : '❌ Temp/RH ESP32 disconnected at $tempEspIP:$_tempPort '
              '($_tempEspFailures failed polls)');
    }
  }

  /// GETs [uri] and hands the decoded JSON to [apply].
  /// Returns true only on a 200 response that parsed.
  Future<bool> _get(Uri uri, void Function(Map<String, dynamic>) apply) async {
    final path = uri.path;
    try {
      final resp = await http.get(uri).timeout(_requestTimeout);
      if (resp.statusCode != 200) {
        debugPrint('OTPanelProvider: $path returned ${resp.statusCode}');
        return false;
      }
      apply(jsonDecode(resp.body) as Map<String, dynamic>);
      return true;
    } catch (e) {
      debugPrint('OTPanelProvider: $path failed: $e');
      return false;
    }
  }

  void _applyLights(Map<String, dynamic> data) {
    if (_pendingLightWrites > 0) return;
    for (var i = 0; i < 8; i++) {
      lightStates[i] = data['light${i + 1}'] == true;
    }
  }

  void _applyPressure(Map<String, dynamic> data) {
    // Negative readings are shown as 0. Use <= so -0.0 / tiny negatives
    // don't render as "-0.00".
    final pa = _toDouble(data['pressure_pa']);
    pressurePa = pa <= 0 ? 0.0 : pa;
    pressureRangePa = _toDouble(data['range_pa']);
  }

  /// /api/status → {local: {night_mode, relay_state, gas_state, ...},
  /// second_esp: {online, device_id, temperature, humidity,
  /// temperature_setpoint, humidity_setpoint, ...}}.
  /// relay_state / gas_state are bitmasks: bit 0 = relay / zone 1.
  /// `second_esp` is applied in _fetchStatus.
  void _applyStatus(Map<String, dynamic> data) {
    final local = data['local'];
    if (local is Map) {
      nightModeActive = local['night_mode'] == true;
      final relays = local['relay_state'];
      if (relays is num && _pendingLightWrites == 0) {
        for (var i = 0; i < _waveshareRelayCount; i++) {
          lightStates[i] = (relays.toInt() >> i) & 1 == 1;
        }
      }
      final gas = local['gas_state'];
      if (gas is num) {
        for (var i = 0; i < gasZoneFull.length; i++) {
          gasZoneFull[i] = (gas.toInt() >> i) & 1 == 1;
        }
      }
    }
    final second = data['second_esp'];
    if (second is Map) {
      _lastWaveshareSecondEsp = second.cast<String, dynamic>();
    }
  }

  /// Waveshare-relayed slave data: numbers in real units (24.0, not 240).
  void _applyWaveshareSecondEsp(Map<String, dynamic> second) {
    secondEspDataReceived = true;
    temperature = _toDouble(second['temperature']);
    humidity = _toDouble(second['humidity']);

    final now = DateTime.now();
    if (!_guardActive(_tempSetpointGuardUntil, now)) {
      temperatureSetpoint = _toDouble(second['temperature_setpoint']);
    }
    if (!_guardActive(_humSetpointGuardUntil, now)) {
      humiditySetpoint = _toDouble(second['humidity_setpoint']);
    }
  }

  /// /all-parameters → {"temperature":"26.5", "humidity":"55.0",
  /// "temp_setpoint":"240", "humidity_setpoint":"500", "data_received":true,
  /// "light_status":[0,1,...], "sensor_faults":[0,1,...], ...}.
  /// Readings are real units, setpoints are ×10, all as strings.
  void _applySensorData(Map<String, dynamic> data) {
    secondEspDataReceived = data['data_received'] == true;
    // Until the AHU controller has sent a packet, the ESP32 serves its
    // built-in defaults — keep the last good values instead.
    if (!secondEspDataReceived) return;

    // Lights/MGPS are applied in _fetchStatus once both polls are done and
    // we know whether a Waveshare answered.
    _lastEspIo = data;

    // The Waveshare's second_esp data takes priority (see _fetchStatus).
    if (_tempViaWaveshare) return;

    temperature = _toDouble(data['temperature']);
    humidity = _toDouble(data['humidity']);

    final now = DateTime.now();
    if (!_guardActive(_tempSetpointGuardUntil, now)) {
      temperatureSetpoint = _toDouble(data['temp_setpoint']) / 10;
    }
    if (!_guardActive(_humSetpointGuardUntil, now)) {
      humiditySetpoint = _toDouble(data['humidity_setpoint']) / 10;
    }
  }

  /// light_status: [0|1, ...] for lights 1-10. [from] is the first
  /// 0-based index to apply.
  void _applyEspLights(dynamic list, {int from = 0}) {
    if (list is! List || _pendingLightWrites > 0) return;
    final now = DateTime.now();
    for (var i = from; i < lightStates.length && i < list.length; i++) {
      if (_guardActive(_espLightGuardUntil[i], now)) continue;
      lightStates[i] = _toDouble(list[i]) == 1;
    }
  }

  /// /all-parameters "pressure2": signed Pa as a string, with the board's
  /// offset/scale calibration already applied (C_PRESSURE_2 over RS485).
  void _applyEspPressure(Map<String, dynamic> data) {
    if (!data.containsKey('pressure2')) return;
    final pa = _toDouble(data['pressure2']);
    pressurePa = pa <= 0 ? 0.0 : pa;
  }

  /// sensor_faults: [0|1, ...] for sensors 1-10 (F_Sensor_N_FAULT_BIT).
  /// A fault means that gas line is low/empty; the MGPS screen uses 1-8.
  void _applyEspSensorFaults(dynamic list) {
    if (list is! List) return;
    for (var i = 0; i < gasZoneFull.length && i < list.length; i++) {
      gasZoneFull[i] = _toDouble(list[i]) != 1;
    }
  }

  bool _guardActive(DateTime? until, DateTime now) =>
      until != null && now.isBefore(until);

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  // ── Light control ────────────────────────────────────────────────

  /// Sets a single relay (1-10). Updates the UI immediately (optimistic),
  /// then rolls back if the write actually failed. Relays 9 and 10 always
  /// go to the espwifipp board — the Waveshare only has 8.
  Future<bool> setLight(int id, bool state) async {
    if (id < 1 || id > lightStates.length) return false;
    if (_espIsIoSource || id > _waveshareRelayCount) {
      return _setEspLights({id: state});
    }
    final previous = lightStates[id - 1];
    _pendingLightWrites++;
    lightStates[id - 1] = state;
    notifyListeners();
    try {
      final resp = await http
          .post(
            _uri('/api/light'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': id, 'state': state}),
          )
          .timeout(_requestTimeout);
      final ok = resp.statusCode == 200;
      if (!ok) {
        lightStates[id - 1] = previous;
        debugPrint('OTPanelProvider: setLight($id) failed with status ${resp.statusCode}');
      } else {
        debugPrint('OTPanelProvider: setLight($id) to $state - SUCCESS');
      }
      return ok;
    } catch (e) {
      lightStates[id - 1] = previous;
      debugPrint('OTPanelProvider: setLight($id) failed: $e');
      return false;
    } finally {
      _pendingLightWrites--;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<bool> toggleLight(int id) async {
    if (id < 1 || id > lightStates.length) return false;
    return setLight(id, !lightStates[id - 1]);
  }

  /// All lights on/off.
  Future<bool> setAllLights(bool state) async {
    if (_espIsIoSource) {
      return _setEspLights({for (var id = 1; id <= 8; id++) id: state});
    }
    final previous = List<bool>.from(lightStates);
    _pendingLightWrites++;
    for (var i = 0; i < 8; i++) {
      lightStates[i] = state;
    }
    notifyListeners();
    try {
      final resp = await http
          .post(
            _uri('/api/lights/all'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'state': state}),
          )
          .timeout(_requestTimeout);
      final ok = resp.statusCode == 200;
      if (!ok) lightStates.setAll(0, previous);
      return ok;
    } catch (e) {
      lightStates.setAll(0, previous);
      debugPrint('OTPanelProvider: setAllLights failed: $e');
      return false;
    } finally {
      _pendingLightWrites--;
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Sets several lights at once, e.g. {1: true, 2: true, 3: true, 4: true}.
  /// On the ESP32 this is a single /control write, so they all switch
  /// together. The Waveshare has no "subset" endpoint (only /api/lights/all,
  /// which flips all 8 relays), so there it falls back to one call per light.
  Future<bool> setLights(Map<int, bool> states) async {
    states.removeWhere((id, _) => id < 1 || id > lightStates.length);
    if (states.isEmpty) return false;
    if (_espIsIoSource) return _setEspLights(states);
    final results = await Future.wait(
      states.entries.map((e) => setLight(e.key, e.value)),
    );
    return results.every((r) => r);
  }

  /// Switches lights on the temp/RH ESP32 in one POST /control
  /// (S_Light_N_ON_OFF = "1"/"0"), which relays them over RS485.
  /// Optimistic: updates [lightStates] first, rolls back on failure.
  Future<bool> _setEspLights(Map<int, bool> states) async {
    final previous = List<bool>.from(lightStates);
    final guardUntil = DateTime.now().add(_setpointGuard);
    _pendingLightWrites++;
    states.forEach((id, on) {
      lightStates[id - 1] = on;
      _espLightGuardUntil[id - 1] = guardUntil;
    });
    notifyListeners();

    final fields = {
      for (final e in states.entries) 'S_Light_${e.key}_ON_OFF': e.value ? '1' : '0',
    };
    var ok = false;
    try {
      final resp = await http
          .post(_tempUri('/control'), body: fields)
          .timeout(_requestTimeout);
      final body = jsonDecode(resp.body);
      ok = resp.statusCode == 200 && body is Map && body['status'] == 'success';
      debugPrint(ok
          ? 'OTPanelProvider: ESP lights $fields - SUCCESS'
          : 'OTPanelProvider: ESP lights $fields failed (${resp.statusCode}): ${resp.body}');
    } catch (e) {
      debugPrint('OTPanelProvider: ESP lights $fields failed: $e');
    } finally {
      if (!ok) {
        lightStates.setAll(0, previous);
        for (final id in states.keys) {
          _espLightGuardUntil[id - 1] = null;
        }
      }
      _pendingLightWrites--;
      if (!_isDisposed) notifyListeners();
    }
    return ok;
  }

  // ── Night mode ───────────────────────────────────────────────────

  /// Turns night mode on/off via POST /api/night. The firmware saves and
  /// restores lights 1-4 itself, so don't drive relay 6 directly.
  Future<bool> setNightMode(bool on) async {
    try {
      final resp = await http
          .post(
            _uri('/api/night'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'state': on}),
          )
          .timeout(_requestTimeout);
      if (resp.statusCode != 200) {
        debugPrint('OTPanelProvider: setNightMode($on) failed with status ${resp.statusCode}');
        return false;
      }
      final body = jsonDecode(resp.body);
      nightModeActive = body is Map ? body['state'] == true : on;
      // Night mode changes several relays at once — re-read them all.
      await _get(_uri('/api/lights'), _applyLights);
      return true;
    } catch (e) {
      debugPrint('OTPanelProvider: setNightMode($on) failed: $e');
      return false;
    } finally {
      if (!_isDisposed) notifyListeners();
    }
  }

  // ── Second ESP32: Temperature / Humidity setpoints ─────────────────

  /// Sends a new temperature setpoint — to the espwifipp board's /control
  /// (S_TEMP_SETPT) if it is reachable, otherwise through the Waveshare
  /// (/api/temperature/setpoint), which forwards it to its slave ESP32.
  Future<bool> setTemperatureSetpoint(double value) async {
    final previous = temperatureSetpoint;
    temperatureSetpoint = value;
    _tempSetpointGuardUntil = DateTime.now().add(_setpointGuard);
    notifyListeners();

    final ok = _tempEspDirectOnline && !_tempViaWaveshare
        ? await _postSetpoint('S_TEMP_SETPT', value)
        : await _postWaveshareSetpoint('/api/temperature/setpoint', value);
    if (!ok) {
      temperatureSetpoint = previous;
      _tempSetpointGuardUntil = null;
    }
    if (!_isDisposed) notifyListeners();
    return ok;
  }

  /// Sends a new humidity setpoint (S_RH_SETPT directly, or
  /// /api/humidity/setpoint through the Waveshare).
  Future<bool> setHumiditySetpoint(double value) async {
    final previous = humiditySetpoint;
    humiditySetpoint = value;
    _humSetpointGuardUntil = DateTime.now().add(_setpointGuard);
    notifyListeners();

    final ok = _tempEspDirectOnline && !_tempViaWaveshare
        ? await _postSetpoint('S_RH_SETPT', value)
        : await _postWaveshareSetpoint('/api/humidity/setpoint', value);
    if (!ok) {
      humiditySetpoint = previous;
      _humSetpointGuardUntil = null;
    }
    if (!_isDisposed) notifyListeners();
    return ok;
  }

  /// POST /control with a form field. The firmware stores setpoints as
  /// value×10 zero-padded to 3 digits ("240" = 24.0) and answers
  /// {"status":"success", ...} with 200.
  Future<bool> _postSetpoint(String field, double value) async {
    final raw = (value * 10).round().toString().padLeft(3, '0');
    try {
      final resp = await http
          .post(_tempUri('/control'), body: {field: raw})
          .timeout(_requestTimeout);
      final body = jsonDecode(resp.body);
      final ok = resp.statusCode == 200 &&
          body is Map &&
          body['status'] == 'success';
      debugPrint(ok
          ? 'OTPanelProvider: $field=$raw - SUCCESS'
          : 'OTPanelProvider: $field=$raw failed (${resp.statusCode}): ${resp.body}');
      return ok;
    } catch (e) {
      debugPrint('OTPanelProvider: $field=$raw failed: $e');
      return false;
    }
  }

  /// POST {"value": v} (real units) to the Waveshare, which forwards it to
  /// its slave ESP32: 200 {"ok":true,"forwarded":true}, 503 if the slave
  /// is offline.
  Future<bool> _postWaveshareSetpoint(String path, double value) async {
    try {
      final resp = await http
          .post(
            _uri(path),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'value': value}),
          )
          .timeout(_requestTimeout);
      final ok = resp.statusCode == 200;
      debugPrint(ok
          ? 'OTPanelProvider: $path($value) - SUCCESS'
          : 'OTPanelProvider: $path($value) failed (${resp.statusCode}): ${resp.body}');
      return ok;
    } catch (e) {
      debugPrint('OTPanelProvider: $path($value) failed: $e');
      return false;
    }
  }

  /// Stop polling - call this from dispose()
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Force a refresh of the status
  Future<void> refreshData() async {
    await _fetchStatus();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }
}
