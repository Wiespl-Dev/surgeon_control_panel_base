import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:typed_data';

class GlobalUsbProvider with ChangeNotifier {
  // USB Connection - Multiple ports support

  String? get someValue => _prefs?.getString("key");
  List<UsbPort> _ports = [];
  Map<String, UsbPort> _devicePortMap = {};
  Map<String, UsbDevice> _deviceMap = {}; // Store UsbDevice objects
  String usbStatus = "Disconnected";
  bool isConnected = false;
  String _incomingBuffer = "";
  Map<String, StreamSubscription<Uint8List>> _inputStreamSubscriptions = {};
  StreamSubscription<UsbEvent>? _usbEventSubscription;

  // Store granted device permissions
  Map<String, bool> _grantedPermissions = {};

  // FIXED: Removed debouncing that was blocking updates
  DateTime? _lastUiUpdateTime;
  static const Duration _minUiUpdateInterval = Duration(
    milliseconds: 100,
  ); // Reduced to allow more frequent updates

  static final List<Map<String, int>> _supportedDevices = [
    // CH340/CH341 Devices
    {'vid': 6790, 'pid': 29987}, // 0x1A86, 0x7523 - CH340
    {'vid': 6790, 'pid': 29986}, // CH340 variant
    {'vid': 6790, 'pid': 29985}, // CH340 variant
    // CH343 Devices - EXPANDED LIST
    {'vid': 6790, 'pid': 29989}, // CH343
    {'vid': 6790, 'pid': 29990}, // CH343 variant
    {'vid': 6790, 'pid': 29991}, // CH343 variant
    {'vid': 6790, 'pid': 29992}, // CH343G
    {'vid': 6790, 'pid': 21971},
    {'vid': 6790, 'pid': 29993}, // CH343 variant
    {'vid': 6790, 'pid': 29994}, // CH343 variant
    {'vid': 6790, 'pid': 29995}, // CH343 variant
    {'vid': 6790, 'pid': 29996}, // CH343 variant
    // FTDI Devices
    {'vid': 1027, 'pid': 24577}, // FT232R
    {'vid': 1027, 'pid': 24592}, // FT232H
    {'vid': 1027, 'pid': 24596}, // FT2232H
    {'vid': 1027, 'pid': 24600}, // FT4232H
    // Prolific Devices
    {'vid': 1659, 'pid': 8963}, // PL2303
    {'vid': 1659, 'pid': 36880}, // PL2303GC
    // CP210x Devices
    {'vid': 4292, 'pid': 60000}, // CP2102
    {'vid': 4292, 'pid': 60001}, // CP2102
    // Arduino Devices
    {'vid': 9025, 'pid': 66}, // Arduino Uno
    {'vid': 9025, 'pid': 67}, // Arduino Mega
  ];

  // Temperature State
  double _pendingTemperature = 25.0;
  String _temp = "--";
  String _receivedData = "";
  // Humidity State
  double _pendingHumidity = 50.0;
  String _humidity = "--";

  // Light State
  List<int> _lightIntensities = List.filled(7, 0);
  List<bool> _lightStates = List.filled(7, false);
  bool _nightMode = false;

  // System Status
  bool _isSwitched = false;

  // HEPA Status
  bool _isHepaHealthy = true;
  String _hepaStatusText = "HEPA Healthy";

  // OR Status Provider Functions
  bool _defumigation = false; // Light 9
  bool _orNightMode = false; // Light 8
  int _pressure1 = 0; // C_PRESSURE_1 with sign
  bool _isPressurePositive = true; // Track pressure sign

  // Audio functionality
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMuted = false;
  bool _isAlertPlaying = false;

  // Message tracking
  String? lastReceivedValue;
  String? lastSentMessage;

  late SharedPreferences _prefs;
  bool _isInitialized = false;
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Auto-reconnect mechanism
  Timer? _reconnectTimer;
  Timer? _statusRequestTimer;
  bool _manualDisconnect = false;
  static const Duration _reconnectInterval = Duration(seconds: 5);
  static const Duration _statusRequestInterval = Duration(
    seconds: 3,
  ); // Reduced for faster updates

  // Command protection
  DateTime? _lastCommandTime;
  static const Duration _commandCooldown = Duration(milliseconds: 500);
  bool _isSendingCommand = false;

  // Multi-port management
  String? _activeDeviceId;
  List<UsbDevice> _availableDevices = [];

  // Data update tracking
  int _dataUpdateCount = 0;

  // Pressure adjustment
  double _pressureOffset = 0.0;
  bool _hasManualAdjustment = false;

  // SharedPreferences keys
  static const String _pressureOffsetKey = 'pressure_offset_usb';
  static const String _hasManualAdjustmentKey = 'has_manual_adjustment_usb';
  static const String _usbPermissionsKey = 'usb_granted_permissions';

  // Getters
  double get pendingTemperature => _pendingTemperature;
  String get currentTemperature => _temp;
  double get pendingHumidity => _pendingHumidity;
  String get currentHumidity => _humidity;
  List<int> get lightIntensities => _lightIntensities;
  List<bool> get lightStates => _lightStates;
  bool get nightMode => _nightMode;
  bool get allLightsState => _lightStates.any((state) => state);
  String get receivedData => _receivedData;
  bool get isSwitched => _isSwitched;
  bool get isHepaHealthy => _isHepaHealthy;
  String get hepaStatusText => _hepaStatusText;
  bool get defumigation => _defumigation;
  bool get orNightMode => _orNightMode;
  int get pressure1 => _pressure1;
  bool get isPressurePositive => _isPressurePositive;
  List<UsbDevice> get availableDevices => _availableDevices;
  String? get activeDeviceId => _activeDeviceId;
  AudioPlayer get audioPlayer => _audioPlayer;
  bool get isMuted => _isMuted;
  bool get isAlertPlaying => _isAlertPlaying;
  double get pressureOffset => _pressureOffset;
  bool get hasManualAdjustment => _hasManualAdjustment;

  // FIXED: Initialize shared preferences - ONLY load settings, NOT sensor data
  Future<void> initSharedPreferences() async {
    if (_isInitialized) {
      print("GlobalUsbProvider already initialized, skipping...");
      return;
    }

    try {
      _prefs = await SharedPreferences.getInstance();

      // ✅ CRITICAL FIX: DO NOT load temperature/humidity from SharedPreferences
      // Let USB data populate these values
      // Keep initial values as "--"
      _temp = "--";
      _humidity = "--";

      // ✅ Load setpoints (user settings)
      _pendingTemperature = _prefs.getDouble('setpoint_temperature') ?? 25.0;
      _pendingHumidity = _prefs.getDouble('setpoint_humidity') ?? 50.0;

      // Load other settings
      _isSwitched = _prefs.getBool('system_switched') ?? false;
      _defumigation = _prefs.getBool('or_defumigation') ?? false;
      _orNightMode = _prefs.getBool('or_night_mode') ?? false;

      // Load light settings
      List<String>? intensityStrings = _prefs.getStringList(
        'light_intensities',
      );
      List<String>? stateStrings = _prefs.getStringList('light_states');

      if (intensityStrings != null &&
          stateStrings != null &&
          intensityStrings.length == 7 &&
          stateStrings.length == 7) {
        _lightIntensities = intensityStrings
            .map((s) => int.tryParse(s) ?? 0)
            .toList();
        _lightStates = stateStrings.map((s) => s == 'true').toList();
        _nightMode = !_lightStates.any((state) => state);
      } else {
        _lightStates = List.filled(7, false);
        _lightIntensities = List.filled(7, 0);
        _nightMode = true;
        await _saveLightSettings();
      }

      // Load HEPA status
      refreshHepaStatus();

      // Load last connected device
      _activeDeviceId = _prefs.getString('last_connected_device');
      _pressureOffset = _prefs.getDouble(_pressureOffsetKey) ?? 0.0;
      _hasManualAdjustment = _prefs.getBool(_hasManualAdjustmentKey) ?? false;

      // Load permissions
      await _loadGrantedPermissions();

      _isInitialized = true;
      print("✅ GlobalUsbProvider initialized - waiting for USB data");

      // Start USB monitoring
      startUsbMonitoring();

      notifyListeners();
    } catch (e) {
      print("❌ Error initializing SharedPreferences: $e");
    }
  }

  // Load granted USB permissions from SharedPreferences
  Future<void> _loadGrantedPermissions() async {
    try {
      final permissionsString = _prefs.getString(_usbPermissionsKey);
      if (permissionsString != null && permissionsString.isNotEmpty) {
        final permissions = permissionsString.split(',');
        for (var permission in permissions) {
          final parts = permission.split(':');
          if (parts.length == 2) {
            _grantedPermissions[parts[0]] = parts[1] == '1';
          }
        }
        print("✅ Loaded ${_grantedPermissions.length} granted USB permissions");
      }
    } catch (e) {
      print("❌ Error loading USB permissions: $e");
    }
  }

  // Save granted USB permissions to SharedPreferences
  Future<void> _saveGrantedPermissions() async {
    try {
      final permissionsList = _grantedPermissions.entries
          .map((entry) => '${entry.key}:${entry.value ? '1' : '0'}')
          .toList();
      final permissionsString = permissionsList.join(',');
      await _prefs.setString(_usbPermissionsKey, permissionsString);
      print("💾 Saved ${_grantedPermissions.length} USB permissions");
    } catch (e) {
      print("❌ Error saving USB permissions: $e");
    }
  }

  // NEW METHOD: Batch update all lights at once
  void setAllLightsState(bool state, int intensity) {
    for (int i = 0; i < _lightStates.length; i++) {
      _lightStates[i] = state;
      _lightIntensities[i] = state ? intensity : 0;
    }

    _nightMode = !state;
    _saveLightSettings();

    print("💡 All lights ${state ? 'ON' : 'OFF'} with intensity $intensity");
    print("   Light states: $_lightStates");
    print("   Light intensities: $_lightIntensities");

    notifyListeners();
  }

  // Enhanced USB Monitoring with better debugging
  void startUsbMonitoring() {
    print("🚀 Starting USB Monitoring...");

    // 1. Initial connection attempt
    initUsb();

    // 2. Start listening for USB events with better error handling
    _usbEventSubscription?.cancel();

    if (UsbSerial.usbEventStream == null) {
      print(
        "❌ USB Event Stream is null - USB monitoring may not work properly",
      );
      // Fallback: use periodic scanning instead
      _startPeriodicScanning();
      return;
    }

    _usbEventSubscription = UsbSerial.usbEventStream!.listen(
      (UsbEvent event) {
        print(
          "🔌 USB Event: ${event.event} - Device: ${event.device?.deviceName ?? 'Unknown'}",
        );

        if (event.event == UsbEvent.ACTION_USB_ATTACHED) {
          print(
            "📱 USB Device Attached - VID: ${event.device?.vid}, PID: ${event.device?.pid}",
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (!isConnected && !_manualDisconnect) {
              print("🔄 USB ATTACHED: Attempting connection...");
              initUsb();
            }
          });
        } else if (event.event == UsbEvent.ACTION_USB_DETACHED) {
          final deviceId = _getDeviceId(event.device);
          print("📵 USB Device Detached: $deviceId");
          if (_devicePortMap.containsKey(deviceId)) {
            _handleConnectionLoss(deviceId);
          }
        }
      },
      onError: (error) {
        print("❌ USB Event Stream Error: $error");
        _startPeriodicScanning(); // Fallback to periodic scanning
      },
      cancelOnError: false,
    );

    // 3. Start auto-reconnect as fallback
    _startAutoReconnectTimer();
  }

  // Fallback periodic scanning if event stream fails
  void _startPeriodicScanning() {
    print("🔄 Starting periodic USB scanning...");
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!isConnected && !_manualDisconnect) {
        print("⏰ Periodic scan: Checking for USB devices...");
        initUsb();
      }
    });
  }

  // Enhanced USB initialization with comprehensive debugging
  Future<void> initUsb({int retry = 0}) async {
    try {
      print("🔄 initUsb called (attempt ${retry + 1})");

      if (isConnected && _ports.isNotEmpty) {
        print("ℹ️ Already connected, skipping...");
        return;
      }

      usbStatus = "Scanning for USB devices... (attempt ${retry + 1})";
      notifyListeners();

      // Give time for system to recognize new devices
      if (retry == 0) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      print("🔍 Listing USB devices...");
      List<UsbDevice> devices = await UsbSerial.listDevices();
      print("📋 Found ${devices.length} total USB devices");

      // Log all devices for debugging
      for (var device in devices) {
        final deviceId = _getDeviceId(device);
        final hasPermission = _grantedPermissions[deviceId] ?? false;
        print(
          "🔧 Device: ${device.deviceName} - VID: ${device.vid}, PID: ${device.pid}, Supported: ${_isDeviceSupported(device)}, Permission: ${hasPermission ? 'Granted' : 'Not Granted'}",
        );
      }

      _availableDevices = devices.where(_isDeviceSupported).toList();
      print("✅ Found ${_availableDevices.length} supported USB devices");

      if (_availableDevices.isEmpty) {
        if (retry < 3) {
          print("⚠️ No supported devices found, retrying in 2 seconds...");
          await Future.delayed(const Duration(seconds: 2));
          return initUsb(retry: retry + 1);
        }
        usbStatus = "No supported USB devices found";
        isConnected = false;
        notifyListeners();
        _startAutoReconnectTimer();
        return;
      }

      // Try to connect to all supported devices
      bool anyConnected = false;
      for (var device in _availableDevices) {
        final deviceId = _getDeviceId(device);
        print(
          "🔌 Attempting to connect to: ${_getDeviceDisplayName(device)} ($deviceId)",
        );

        try {
          // Store the device object
          _deviceMap[deviceId] = device;

          // Check if we have permission stored for this device
          final hasPermission = _grantedPermissions[deviceId] ?? false;

          // Request permission if we don't have it stored
          bool permissionGranted = hasPermission;
          if (!permissionGranted) {
            print("🔑 Requesting permission for device: $deviceId");

            // For usb_serial package, we need to check if permission is granted
            // The actual permission request might be handled by the system
            // when we try to open the port

            // Try to create port first
            final port = await device.create();
            if (port == null) {
              print("❌ Failed to create port for device: $deviceId");
              continue;
            }

            // Try to open the port (this might trigger permission request)
            bool open = await port.open();

            if (!open) {
              print(
                "❌ Failed to open port for device: $deviceId (permission may be denied)",
              );
              port.close();
              continue;
            }

            // If we get here, permission was granted
            permissionGranted = true;
            _grantedPermissions[deviceId] = true;
            await _saveGrantedPermissions();

            // Configure port and store it
            await _configureAndStorePort(port, deviceId, device);
            anyConnected = true;
          } else {
            // We have stored permission, try to connect
            final port = await device.create();
            if (port == null) {
              print("❌ Failed to create port for device: $deviceId");
              continue;
            }

            bool open = await port.open();
            if (!open) {
              print(
                "⚠️ Stored permission may have been revoked for: $deviceId",
              );
              // Permission might have been revoked, remove from stored permissions
              _grantedPermissions.remove(deviceId);
              await _saveGrantedPermissions();
              port.close();
              continue;
            }

            // Configure port and store it
            await _configureAndStorePort(port, deviceId, device);
            anyConnected = true;
          }
        } catch (e) {
          print("❌ Connection error for ${_getDeviceDisplayName(device)}: $e");
        }
      }

      if (anyConnected) {
        // Set active device
        if (_activeDeviceId != null &&
            _devicePortMap.containsKey(_activeDeviceId)) {
          print("🎯 Using previously active device: $_activeDeviceId");
        } else if (_devicePortMap.isNotEmpty) {
          _activeDeviceId = _devicePortMap.keys.first;
          _prefs.setString('last_connected_device', _activeDeviceId!);
          print("🎯 Set active device to: $_activeDeviceId");
        }

        isConnected = true;
        _manualDisconnect = false;
        usbStatus = "Connected to ${_devicePortMap.length} device(s)";

        _reconnectTimer?.cancel();
        // _startStatusRequestTimer();

        print("🎉 USB Connection established successfully!");

        // Send initial status request
        Future.delayed(const Duration(seconds: 1), () {
          sendCompleteStructure();
        });
      } else {
        usbStatus = "Failed to connect to any supported devices";
        isConnected = false;
        _cleanupConnection();
        _startAutoReconnectTimer();
        print("❌ Failed to establish any USB connections");
      }

      notifyListeners();
    } catch (e) {
      print("💥 USB init error: $e");
      usbStatus = "Error: $e";
      isConnected = false;
      _cleanupConnection();
      notifyListeners();

      _startAutoReconnectTimer();
    }
  }

  // Helper method to configure and store a connected port
  Future<void> _configureAndStorePort(
    UsbPort port,
    String deviceId,
    UsbDevice device,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));

    // Configure port settings
    await port.setDTR(true);
    await port.setRTS(true);
    await port.setPortParameters(9600, 8, 1, 0);

    _ports.add(port);
    _devicePortMap[deviceId] = port;

    // Set up input stream listener
    print("🎧 Setting up input stream for: $deviceId");
    _inputStreamSubscriptions[deviceId] = port.inputStream!.listen(
      (data) => _onDataReceived(data, deviceId),
      onError: (error) {
        print("❌ Stream error for $deviceId: $error");
        _handleConnectionLoss(deviceId);
      },
      onDone: () {
        print("📴 Stream closed for device: $deviceId");
        _handleConnectionLoss(deviceId);
      },
      cancelOnError: false,
    );

    print("✅ Successfully connected to: ${_getDeviceDisplayName(device)}");
  }

  // Enhanced device detection methods
  String _getDeviceId(UsbDevice? device) {
    if (device == null) return 'unknown';
    return '${device.vid}:${device.pid}:${device.deviceId}';
  }

  bool _isDeviceSupported(UsbDevice device) {
    bool supported = _supportedDevices.any(
      (supportedDevice) =>
          device.vid == supportedDevice['vid'] &&
          device.pid == supportedDevice['pid'],
    );

    if (supported) {
      print(
        "👍 Device supported: ${device.vid}:${device.pid} - ${_getDeviceDisplayName(device)}",
      );
    } else {
      print("👎 Device NOT supported: ${device.vid}:${device.pid}");
    }

    return supported;
  }

  String _getDeviceDisplayName(UsbDevice device) {
    // CH340/CH341
    if (device.vid == 6790 && [29987, 29986, 29985].contains(device.pid)) {
      return "CH340 Serial Converter";
    }
    // CH343
    else if (device.vid == 6790 &&
        device.pid! >= 29989 &&
        device.pid! <= 29996) {
      return "CH343 Serial Converter";
    }
    // FTDI
    else if (device.vid == 1027) {
      switch (device.pid) {
        case 24577:
          return "FTDI FT232R";
        case 24592:
          return "FTDI FT232H";
        case 24596:
          return "FTDI FT2232H";
        case 24600:
          return "FTDI FT4232H";
        default:
          return "FTDI USB-Serial";
      }
    }
    // Prolific
    else if (device.vid == 1659) {
      return "Prolific PL2303";
    }
    // CP210x
    else if (device.vid == 4292) {
      return "CP210x Serial Converter";
    }
    // Arduino
    else if (device.vid == 9025) {
      return "Arduino Board";
    }
    // Generic
    else {
      return "USB Serial (${device.vid}:${device.pid})";
    }
  }

  void _handleConnectionLoss([String? deviceId]) {
    print("🔌 Handling connection loss for: ${deviceId ?? 'all devices'}");

    if (deviceId != null) {
      _cleanupConnection(deviceId);

      if (_devicePortMap.isEmpty) {
        isConnected = false;
        usbStatus = "All connections lost, reconnecting...";
        if (!_manualDisconnect) {
          _startAutoReconnectTimer();
        }
      } else {
        if (_activeDeviceId == deviceId) {
          _activeDeviceId = _devicePortMap.keys.first;
          usbStatus = "Switched to backup device";
          print("🔄 Switched active device to: $_activeDeviceId");
        }
      }
    } else {
      isConnected = false;
      usbStatus = "Connection lost, reconnecting...";
      _cleanupConnection();
      if (!_manualDisconnect) {
        _startAutoReconnectTimer();
      }
    }

    notifyListeners();
  }

  void _cleanupConnection([String? deviceId]) {
    if (deviceId != null) {
      // Cleanup specific device
      _inputStreamSubscriptions[deviceId]?.cancel();
      _inputStreamSubscriptions.remove(deviceId);

      final port = _devicePortMap[deviceId];
      port?.close();
      _devicePortMap.remove(deviceId);
      _ports.remove(port);
      _deviceMap.remove(deviceId);

      if (_activeDeviceId == deviceId) {
        _activeDeviceId = null;
      }
    } else {
      // Cleanup all connections
      _inputStreamSubscriptions.forEach((key, subscription) {
        subscription.cancel();
      });
      _inputStreamSubscriptions.clear();

      _ports.forEach((port) => port.close());
      _ports.clear();
      _devicePortMap.clear();
      _deviceMap.clear();
      _activeDeviceId = null;
    }
  }

  void _startAutoReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(_reconnectInterval, (_) {
      if (!isConnected && !_manualDisconnect) {
        print("🔄 Auto-reconnect: Attempting connection...");
        initUsb();
      }
    });
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
    notifyListeners();
  }

  void setAlertPlaying(bool value) {
    _isAlertPlaying = value;
    notifyListeners();
  }

  Future<void> stopAudio() async {
    await _audioPlayer.stop();
    _isAlertPlaying = false;
    notifyListeners();
  }

  // ✅ FIXED: Temperature update method - ALWAYS update from USB
  void updateTemperature(String temp) {
    final oldValue = _temp;
    _temp = temp;

    print("🌡️ Temperature FORCE updated from USB: $oldValue → $_temp");

    // Trigger UI update immediately
    _triggerUiUpdate();
  }

  // ✅ FIXED: Humidity update method - ALWAYS update from USB
  void updateHumidity(String humidity) {
    final oldValue = _humidity;
    _humidity = humidity;

    print("💧 Humidity FORCE updated from USB: $oldValue → $_humidity");

    // Trigger UI update immediately
    _triggerUiUpdate();
  }

  // ✅ NEW: Centralized UI update trigger with minimal throttling
  void _triggerUiUpdate() {
    final now = DateTime.now();

    // Only throttle to prevent excessive updates (100ms minimum)
    if (_lastUiUpdateTime != null &&
        now.difference(_lastUiUpdateTime!) < _minUiUpdateInterval) {
      // Schedule delayed update
      Future.delayed(_minUiUpdateInterval, () {
        notifyListeners();
        _lastUiUpdateTime = DateTime.now();
      });
      return;
    }

    _lastUiUpdateTime = now;
    notifyListeners();
  }

  // Pressure adjustment method
  void updatePressure(double newAbsolutePressure) {
    // Get current pressure value from sensor (with sign)
    final currentSensorPressure = _isPressurePositive
        ? (_pressure1.abs() / 100.0)
        : -(_pressure1.abs() / 100.0);

    _pressureOffset = newAbsolutePressure - currentSensorPressure;

    print('🔧 Setting pressure offset:');
    print('  - Sensor pressure: $currentSensorPressure');
    print('  - New absolute: $newAbsolutePressure');
    print('  - Offset: $_pressureOffset');

    _hasManualAdjustment = true;
    _savePressureAdjustment();
    notifyListeners();
  }

  // Reset manual adjustment
  void resetManualPressure() {
    print('🔄 Resetting USB manual pressure adjustment');
    _hasManualAdjustment = false;
    _pressureOffset = 0.0;
    _savePressureAdjustment();
    notifyListeners();
  }

  // Save pressure adjustment to SharedPreferences
  Future<void> _savePressureAdjustment() async {
    try {
      await _prefs.setDouble(_pressureOffsetKey, _pressureOffset);
      await _prefs.setBool(_hasManualAdjustmentKey, _hasManualAdjustment);
      print(
        '💾 Saved USB pressure: offset=$_pressureOffset, hasAdjustment=$_hasManualAdjustment',
      );
    } catch (e) {
      print('❌ Error saving USB pressure adjustment: $e');
    }
  }

  // Method to get formatted pressure with adjustment
  String getFormattedPressure() {
    final currentSensorPressure = _pressure1.abs() / 100.0;

    print('📊 getFormattedPressure called:');
    print('  - Raw pressure1: $_pressure1');
    print('  - Sensor pressure: $currentSensorPressure');
    print('  - Pressure offset: $_pressureOffset');
    print('  - Is positive: $_isPressurePositive');
    print('  - Has adjustment: $_hasManualAdjustment');

    // SPECIAL CASE: If sensor reads 0, always show 0 regardless of adjustment
    if (_pressure1 == 0) {
      print('🎯 Sensor pressure is 0 - showing 0');
      return "0";
    }

    if (_hasManualAdjustment) {
      final adjustedPressure = _isPressurePositive
          ? currentSensorPressure + _pressureOffset
          : -currentSensorPressure + _pressureOffset;

      print(
        '🎯 Displaying adjusted pressure: $currentSensorPressure ${_isPressurePositive ? '+' : '-'} $_pressureOffset = $adjustedPressure',
      );
      return adjustedPressure.toStringAsFixed(0);
    } else {
      // Return value with sign
      final absoluteValue = currentSensorPressure;
      return _isPressurePositive
          ? absoluteValue.toStringAsFixed(0)
          : "-${absoluteValue.toStringAsFixed(0)}";
    }
  }

  Color getPressureColor() {
    // SPECIAL CASE: If sensor reads 0, use default color
    if (_pressure1 == 0) {
      return Colors.greenAccent;
    }

    if (_hasManualAdjustment) {
      final currentSensorPressure = _pressure1.abs() / 100.0;
      final adjustedPressure = _isPressurePositive
          ? currentSensorPressure + _pressureOffset
          : -currentSensorPressure + _pressureOffset;

      print('🎨 Pressure color calculation:');
      print('  - Adjusted pressure: $adjustedPressure');
      print('  - Color: ${adjustedPressure >= 0 ? "green" : "red"}');

      return adjustedPressure >= 0 ? Colors.greenAccent : Colors.redAccent;
    }

    return _isPressurePositive ? Colors.greenAccent : Colors.redAccent;
  }

  // ✅ REMOVED: No longer saving current temp/humidity to SharedPreferences
  // Only save setpoints

  void _saveSetpointTemperature(double value) {
    _prefs.setDouble('setpoint_temperature', value);
  }

  void _saveSetpointHumidity(double value) {
    _prefs.setDouble('setpoint_humidity', value);
  }

  // FIXED: Changed from void to Future<void>
  Future<void> _saveLightSettings() async {
    List<String> intensityStrings = _lightIntensities
        .map((i) => i.toString())
        .toList();
    List<String> stateStrings = _lightStates.map((b) => b.toString()).toList();

    await _prefs.setStringList('light_intensities', intensityStrings);
    await _prefs.setStringList('light_states', stateStrings);
  }

  // FIXED: Changed from void to Future<void>
  Future<void> _saveORStatusSettings() async {
    await _prefs.setBool('or_defumigation', _defumigation);
    await _prefs.setBool('or_night_mode', _orNightMode);
  }

  // Temperature methods
  void updatePendingTemperature(double value) {
    _pendingTemperature = value.clamp(15.0, 35.0);
    notifyListeners();
  }

  // Humidity methods
  void updatePendingHumidity(double value) {
    _pendingHumidity = value.clamp(0.0, 100.0);
    notifyListeners();
  }

  // FIXED: Changed to Future<void>
  Future<void> updateSystemStatus(bool status) async {
    _isSwitched = status;
    await _prefs.setBool('system_switched', status);
    notifyListeners();
  }

  // FIXED: Changed to Future<void>
  Future<void> toggleDefumigation(bool newValue) async {
    _defumigation = newValue;
    await _prefs.setBool('or_defumigation', _defumigation);
    sendCompleteStructure();
    notifyListeners();
  }

  // FIXED: Changed to Future<void>
  Future<void> toggleORNightMode(bool newValue) async {
    _orNightMode = newValue;
    await _prefs.setBool('or_night_mode', _orNightMode);
    sendCompleteStructure();
    notifyListeners();
  }

  // ✅ FIXED: _parseStructuredData method - ALWAYS update from USB
  void _parseStructuredData(String data) async {
    try {
      if (!(data.startsWith('{') && data.endsWith('}'))) {
        print("❌ Invalid structured format: $data");
        return;
      }

      final pairs = data.substring(1, data.length - 1).split(',');
      final Map<String, dynamic> parsedData = {};

      // Track changes
      Map<String, String> faultBitUpdates = {};

      for (String pair in pairs) {
        final int separatorIndex = pair.indexOf(':');
        if (separatorIndex == -1) continue;

        final key = pair.substring(0, separatorIndex).trim();
        final value = pair.substring(separatorIndex + 1).trim();
        parsedData[key] = value;

        // Collect fault bits for batch update
        if (key.startsWith('F_Sensor_') && key.endsWith('_FAULT_BIT')) {
          faultBitUpdates[key] = value;
        }
      }

      // ✅ CRITICAL FIX: ALWAYS update temperature from USB - no checking if same
      if (parsedData.containsKey('C_OT_TEMP')) {
        final raw = parsedData['C_OT_TEMP'].toString();
        final parsed = _parseScaledValue(raw, 15.0, 35.0, "Temperature");
        if (parsed != null) {
          final formattedTemp = parsed.toStringAsFixed(1);
          updateTemperature(formattedTemp); // This will ALWAYS update
          print("🌡️ USB Data: Temperature = $formattedTemp°C");
        }
      }

      // ✅ CRITICAL FIX: ALWAYS update humidity from USB - no checking if same
      if (parsedData.containsKey('C_RH')) {
        final raw = parsedData['C_RH'].toString();
        final parsed = _parseScaledValue(raw, 0.0, 100.0, "Humidity");
        if (parsed != null) {
          final formattedHumidity = parsed.toStringAsFixed(1);
          updateHumidity(formattedHumidity); // This will ALWAYS update
          print("💧 USB Data: Humidity = $formattedHumidity%");
        }
      }

      // Update setpoints from parsed data
      if (parsedData.containsKey('S_TEMP_SETPT')) {
        final raw = parsedData['S_TEMP_SETPT'].toString();
        final parsed = _parseScaledValue(raw, 15.0, 35.0, "Set Temperature");
        if (parsed != null && parsed != _pendingTemperature) {
          _pendingTemperature = parsed;
          print("🎯 Set Temperature from PLC: $parsed°C");
        }
      }

      if (parsedData.containsKey('S_RH_SETPT')) {
        final raw = parsedData['S_RH_SETPT'].toString();
        final parsed = _parseScaledValue(raw, 0.0, 100.0, "Set Humidity");
        if (parsed != null && parsed != _pendingHumidity) {
          _pendingHumidity = parsed;
          print("🎯 Set Humidity from PLC: $parsed%");
        }
      }

      // Update pressure
      if (parsedData.containsKey('C_PRESSURE_1')) {
        final sign = parsedData['C_PRESSURE_1_SIGN_BIT'];
        final newPressure = _applySign(
          parsedData['C_PRESSURE_1'] ?? '0',
          sign,
        ).toInt();
        final newIsPositive = sign == '1';

        if (_pressure1 != newPressure || _isPressurePositive != newIsPositive) {
          _pressure1 = newPressure;
          _isPressurePositive = newIsPositive;
          print(
            "🔵 Pressure updated: $_pressure1 (${_isPressurePositive ? '+' : '-'})",
          );
        }
      }

      // Update OR Status Lights
      for (int i = 8; i <= 10; i++) {
        final key = 'S_Light_${i}_ON_OFF';
        if (parsedData.containsKey(key)) {
          final on = parsedData[key] == '1';

          if (i == 8 && _orNightMode != on) {
            _orNightMode = on;
          } else if (i == 9 && _defumigation != on) {
            _defumigation = on;
          } else if (i == 10 && _isSwitched != on) {
            _isSwitched = on;
          }
        }
      }

      // Update Regular Lights
      bool anyLightOn = false;

      for (int i = 1; i <= 7; i++) {
        final onKey = 'S_Light_${i}_ON_OFF';
        final intensityKey = 'S_Light_${i}_Intensity';

        if (parsedData.containsKey(onKey)) {
          final state = parsedData[onKey] == '1';
          if (i - 1 < _lightStates.length) {
            _lightStates[i - 1] = state;
            if (state) anyLightOn = true;
          }
        }

        if (parsedData.containsKey(intensityKey)) {
          try {
            final intensity = int.parse(parsedData[intensityKey].toString());
            if (i - 1 < _lightIntensities.length) {
              _lightIntensities[i - 1] = intensity;
            }
          } catch (e) {
            print("❌ Error parsing $intensityKey: $e");
          }
        }
      }

      _nightMode = !anyLightOn;

      // Batch save fault bits to avoid multiple SharedPreferences writes
      if (faultBitUpdates.isNotEmpty) {
        await _saveFaultBitsBatch(faultBitUpdates);
      }

      // Refresh HEPA status after fault bits are saved
      refreshHepaStatus();

      // Save settings (not sensor data)
      await _saveSettingsState();

      _dataUpdateCount++;
      print("🔄 Data update #$_dataUpdateCount completed");
    } catch (e) {
      print("❌ Error parsing structured data: $e");
      print("❌ Data that caused error: $data");
    }
  }

  // NEW: Batch save fault bits
  Future<void> _saveFaultBitsBatch(Map<String, String> faultBits) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      faultBits.forEach((key, value) {
        prefs.setString(key, value);
      });
      print("💾 Saved ${faultBits.length} fault bits");
    } catch (e) {
      print("❌ Error saving fault bits: $e");
    }
  }

  // ✅ FIXED: Only save settings, NOT sensor data
  Future<void> _saveSettingsState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ ONLY save setpoints (user settings)
      await prefs.setDouble('setpoint_temperature', _pendingTemperature);
      await prefs.setDouble('setpoint_humidity', _pendingHumidity);

      // Save light settings
      await _saveLightSettings();

      // Save OR status
      await _saveORStatusSettings();

      // Save system status
      await prefs.setBool('system_switched', _isSwitched);

      print("💾 Settings saved (sensor data NOT saved)");
    } catch (e) {
      print("❌ Error saving settings state: $e");
    }
  }

  // Sensor Data Methods - Fixed versions above

  // HEPA Status Methods
  void refreshHepaStatus() {
    final faultBit = _prefs.getString('F_Sensor_10_FAULT_BIT') ?? '0';
    _isHepaHealthy = faultBit == '1';
    _hepaStatusText = _isHepaHealthy ? "HEPA Healthy" : "HEPA Fault";
    notifyListeners();
  }

  bool hasSensorFault() {
    for (int i = 1; i <= 7; i++) {
      final faultBit = _prefs.getString('F_Sensor_${i}_FAULT_BIT') ?? '0';
      if (faultBit == '0') return true;
    }
    return false;
  }

  void resetAllSensorsToNoFault() {
    for (int i = 1; i <= 10; i++) {
      _prefs.setString('F_Sensor_${i}_FAULT_BIT', '0');
    }
    refreshHepaStatus();
    notifyListeners();
  }

  // Light methods
  void handleLightChange(int lightIndex, bool? turnOn, int? intensity) {
    if (turnOn != null) {
      _lightStates[lightIndex] = turnOn;
      if (!turnOn) _lightIntensities[lightIndex] = 0;
    }
    if (intensity != null) {
      _lightIntensities[lightIndex] = intensity.clamp(0, 100);
      if (intensity > 0) _lightStates[lightIndex] = true;
    }

    _nightMode = !_lightStates.any((state) => state);

    _saveLightSettings();
    notifyListeners();

    if (isConnected) {
      sendCompleteStructure();
    }
  }

  void toggleNightMode() {
    _nightMode = !_nightMode;
    if (_nightMode) {
      for (int i = 0; i < 7; i++) {
        _lightStates[i] = false;
        _lightIntensities[i] = 0;
      }
    }
    _saveLightSettings();
    if (isConnected) {
      sendCompleteStructure();
    }
    notifyListeners();
  }

  void toggleAllLights() {
    // Check if ALL lights are currently on (state = true AND intensity > 0)
    bool allLightsOn = true;
    for (int i = 0; i < 7; i++) {
      if (!_lightStates[i] || _lightIntensities[i] <= 0) {
        allLightsOn = false;
        break;
      }
    }

    bool newState = !allLightsOn;

    // Use the new batch method instead of individual updates
    setAllLightsState(newState, newState ? 50 : 0);

    if (isConnected) {
      sendCompleteStructure();
    }

    print("💡 All lights ${newState ? 'ON' : 'OFF'}");
  }

  void _onDataReceived(Uint8List data, String deviceId) {
    String str = String.fromCharCodes(data);
    print("📥 Raw data from $deviceId: ${String.fromCharCodes(data)}");

    _incomingBuffer += str;
    _receivedData = _incomingBuffer;

    int newlineIndex;
    while ((newlineIndex = _incomingBuffer.indexOf('\n')) != -1) {
      String completeMessage = _incomingBuffer
          .substring(0, newlineIndex)
          .trim();
      _incomingBuffer = _incomingBuffer.substring(newlineIndex + 1);

      if (completeMessage.isNotEmpty) {
        print("📨 Complete message from $deviceId: $completeMessage");
        _processCompleteMessage(completeMessage, deviceId);
      }
    }

    if (_incomingBuffer.startsWith('{') && _incomingBuffer.endsWith('}')) {
      print("📨 JSON message from $deviceId: $_incomingBuffer");
      _processCompleteMessage(_incomingBuffer, deviceId);
      _incomingBuffer = "";
    }
  }

  void _processCompleteMessage(String completeMessage, String deviceId) {
    lastReceivedValue = completeMessage;
    print("🎯 Processing message from $deviceId: $completeMessage");
    _parseStructuredData(completeMessage);
  }

  double? _parseScaledValue(String raw, double min, double max, String label) {
    try {
      final value = int.parse(raw) / 10.0;
      if (value >= min - 1 && value <= max + 1) return value;
      print("⚠️ $label out of range: $value");
    } catch (e) {
      print("❌ Error parsing $label: $e");
    }
    return null;
  }

  int _applySign(String rawValue, String? signBit) {
    int val = int.tryParse(rawValue) ?? 0;
    if (signBit == null) return val;
    return signBit == '1' ? val : -val;
  }

  // Command protection helper
  bool _canSendCommand() {
    final now = DateTime.now();
    if (_isSendingCommand) {
      print("⏳ Already sending command, please wait");
      return false;
    }

    if (_lastCommandTime != null &&
        now.difference(_lastCommandTime!) < _commandCooldown) {
      print("⏳ Command cooldown - please wait");
      return false;
    }

    if (_ports.isEmpty || !isConnected || _activeDeviceId == null) {
      print("Cannot send - USB not connected");
      return false;
    }

    return true;
  }

  // Get active port
  UsbPort? get _activePort {
    if (_activeDeviceId == null) return null;
    return _devicePortMap[_activeDeviceId];
  }

  void sendTemperatureStructure() {
    if (!_canSendCommand()) return;

    List<String> pairs = [];
    pairs.add('SR_WSL:250028');
    pairs.add('S_IOT_TIMER:0060'); // Add IOT timer

    // Add sensor NO/NC settings
    for (int i = 1; i <= 10; i++) {
      pairs.add('S_Sensor_${i}_NO_NC_SETTING:0');
    }

    for (int i = 1; i <= 10; i++) {
      pairs.add('S_Light_${i}_ON_OFF:${getLightState(i)}');
    }

    for (int i = 1; i <= 10; i++) {
      pairs.add('S_Light_${i}_Intensity:${getLightIntensity(i)}');
    }

    int tempToSend = (_pendingTemperature * 10).toInt();
    String tempValue = tempToSend.toString().padLeft(3, '0');
    pairs.add('S_TEMP_SETPT:$tempValue');

    int humidityToSend = (_pendingHumidity * 10).toInt();
    String humidityValue = humidityToSend.toString().padLeft(3, '0');
    pairs.add('S_RH_SETPT:$humidityValue');

    String command = '{${pairs.join(',')}}\n';
    _sendCommand(command, "TEMPERATURE");
    print("📤 Sent TEMPERATURE - setpoint: $_pendingTemperature°C");
  }

  void sendHumidityStructure() {
    if (!_canSendCommand()) return;

    List<String> pairs = [];
    pairs.add('SR_WSL:250028');
    pairs.add('S_IOT_TIMER:0060'); // Add IOT timer

    // Add sensor NO/NC settings
    for (int i = 1; i <= 10; i++) {
      pairs.add('S_Sensor_${i}_NO_NC_SETTING:0');
    }

    for (int i = 1; i <= 10; i++) {
      pairs.add('S_Light_${i}_ON_OFF:${getLightState(i)}');
    }

    for (int i = 1; i <= 10; i++) {
      pairs.add('S_Light_${i}_Intensity:${getLightIntensity(i)}');
    }

    int tempToSend = (_pendingTemperature * 10).toInt();
    String tempValue = tempToSend.toString().padLeft(3, '0');
    pairs.add('S_TEMP_SETPT:$tempValue');

    int humidityToSend = (_pendingHumidity * 10).toInt();
    String humidityValue = humidityToSend.toString().padLeft(3, '0');
    pairs.add('S_RH_SETPT:$humidityValue');

    String command = '{${pairs.join(',')}}\n';
    _sendCommand(command, "HUMIDITY");
    print("📤 Sent HUMIDITY - setpoint: $_pendingHumidity%");
  }

  void sendCompleteStructure() {
    if (!_canSendCommand()) return;

    List<String> pairs = [];
    pairs.add('SR_WSL:250028');
    pairs.add('S_IOT_TIMER:0060'); // Add IOT timer

    // Add sensor NO/NC settings
    for (int i = 1; i <= 10; i++) {
      pairs.add('S_Sensor_${i}_NO_NC_SETTING:0');
    }

    for (int i = 1; i <= 10; i++) {
      pairs.add('S_Light_${i}_ON_OFF:${getLightState(i)}');
    }

    for (int i = 1; i <= 10; i++) {
      pairs.add('S_Light_${i}_Intensity:${getLightIntensity(i)}');
    }

    int tempToSend = (_pendingTemperature * 10).toInt();
    String tempValue = tempToSend.toString().padLeft(3, '0');
    pairs.add('S_TEMP_SETPT:$tempValue');

    int humidityToSend = (_pendingHumidity * 10).toInt();
    String humidityValue = humidityToSend.toString().padLeft(3, '0');
    pairs.add('S_RH_SETPT:$humidityValue');

    String command = '{${pairs.join(',')}}\n';
    _sendCommand(command, "COMPLETE");
    print("📤 Sent COMPLETE structure");
  }

  // Helper methods
  String getLightState(int index) {
    if (index >= 1 && index <= 7) {
      return _lightStates[index - 1] ? '1' : '0';
    } else if (index == 8) {
      return _orNightMode ? '1' : '0';
    } else if (index == 9) {
      return _defumigation ? '1' : '0';
    } else if (index == 10) {
      return _isSwitched ? '1' : '0';
    }
    return '0';
  }

  String getLightIntensity(int index) {
    if (index >= 1 && index <= 7) {
      return _lightIntensities[index - 1].toString().padLeft(3, '0');
    } else if (index == 8) {
      return _orNightMode ? '080' : '000';
    } else if (index == 9) {
      return _defumigation ? '090' : '000';
    } else if (index == 10) {
      return _isSwitched ? '050' : '000';
    }
    return '000';
  }

  void _sendCommand(String command, String type) {
    if (_activePort == null) return;

    _isSendingCommand = true;
    _lastCommandTime = DateTime.now();

    try {
      _activePort!.write(Uint8List.fromList(command.codeUnits));
      lastSentMessage = command.trim();

      if (type == "TEMPERATURE") {
        _saveSetpointTemperature(_pendingTemperature);
      } else if (type == "HUMIDITY") {
        _saveSetpointHumidity(_pendingHumidity);
      } else if (type == "COMPLETE") {
        _saveSetpointTemperature(_pendingTemperature);
        _saveSetpointHumidity(_pendingHumidity);
      }

      // Fire and forget - don't await these
      _saveLightSettings();
      _saveORStatusSettings();

      print("📤 Sent $type command to $_activeDeviceId: ${command.trim()}");
      notifyListeners();
    } catch (e) {
      print("❌ Error sending command: $e");
    } finally {
      _isSendingCommand = false;
    }
  }

  // Manual reconnect method
  void reconnectUsb() {
    print("🔄 Manual reconnect requested");
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    isConnected = false;
    _cleanupConnection();

    Future.delayed(const Duration(seconds: 1), () {
      initUsb();
    });
  }

  // Test USB communication
  void testUsbCommunication() {
    if (!isConnected) {
      print("❌ Cannot test - USB not connected");
      return;
    }

    print("🧪 Testing USB communication...");
    sendCompleteStructure();

    if (_activePort != null) {
      String testCommand = "TEST\n";
      _activePort!.write(Uint8List.fromList(testCommand.codeUnits));
      print("📤 Sent test command: $testCommand");
    }
  }

  void requestSensorData() {
    if (_activePort != null && isConnected) {
      String command = "GET_SENSORS\n";
      _activePort!.write(Uint8List.fromList(command.codeUnits));
      print("📤 Requested sensor data");
    }
  }

  // FIXED: Changed to Future<void>
  Future<void> toggleSystemPower(bool turnOn) async {
    _isSwitched = turnOn;
    await _prefs.setBool('system_switched', turnOn);

    print("✅ System status updated to: $_isSwitched");
    notifyListeners();

    if (_activePort != null && isConnected) {
      sendCompleteStructure();
      print("📤 System power ${turnOn ? 'ON' : 'OFF'} command sent");
    } else {
      print("⚠️ USB not connected, but UI state updated to: $turnOn");
    }
  }

  // FIXED: Changed to Future<void>
  Future<void> toggleSystem(bool newValue) async {
    await toggleSystemPower(newValue);
  }

  // Method to switch active device
  Future<void> switchActiveDevice(String deviceId) async {
    if (_devicePortMap.containsKey(deviceId)) {
      _activeDeviceId = deviceId;
      await _prefs.setString('last_connected_device', deviceId);
      isConnected = true;
      usbStatus =
          "Connected to ${_getDeviceDisplayName(_getDeviceById(deviceId)!)}";
      notifyListeners();

      sendCompleteStructure();
    }
  }

  // Helper to get device by ID
  UsbDevice? _getDeviceById(String deviceId) {
    try {
      return _availableDevices.firstWhere(
        (device) => _getDeviceId(device) == deviceId,
      );
    } catch (e) {
      return null;
    }
  }

  // Method to disconnect specific device
  void disconnectDevice(String deviceId) {
    _cleanupConnection(deviceId);
    if (_devicePortMap.isEmpty) {
      isConnected = false;
      usbStatus = "Disconnected";
    }
    notifyListeners();
  }

  // Method to get device display info
  Map<String, String> getDeviceInfo(String deviceId) {
    final device = _getDeviceById(deviceId);
    if (device != null) {
      return {
        'name': _getDeviceDisplayName(device),
        'vid': device.vid.toString(),
        'pid': device.pid.toString(),
        'isActive': _activeDeviceId == deviceId ? 'true' : 'false',
      };
    }
    return {};
  }

  // Method to manually clear all USB permissions (for debugging)
  Future<void> clearUsbPermissions() async {
    _grantedPermissions.clear();
    await _prefs.remove(_usbPermissionsKey);
    print("🧹 Cleared all USB permissions");
  }

  // Method to check if a specific device has permission
  bool hasPermissionForDevice(String deviceId) {
    return _grantedPermissions[deviceId] ?? false;
  }

  // Method to get list of devices with permissions
  List<String> getDevicesWithPermissions() {
    return _grantedPermissions.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  @override
  void dispose() {
    print("🧹 Disposing GlobalUsbProvider...");
    _reconnectTimer?.cancel();
    _statusRequestTimer?.cancel();
    _inputStreamSubscriptions.forEach((key, subscription) {
      subscription.cancel();
    });
    _inputStreamSubscriptions.clear();
    _usbEventSubscription?.cancel();
    _ports.forEach((port) => port.close());
    _audioPlayer.dispose();
    super.dispose();
  }
}
