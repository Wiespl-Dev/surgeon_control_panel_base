import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Import your providers
import '../services/nnn.dart'; // OTPanelProvider (temp/humidity, pressure, relays) - Port 80

class ORStatusMonitor extends StatefulWidget {
  @override
  State<ORStatusMonitor> createState() => _ORStatusMonitorState();
}

class _ORStatusMonitorState extends State<ORStatusMonitor>
    with TickerProviderStateMixin {
  // Default IP (will be overridden by SharedPreferences if available)
  String _pressureRelayIP = '192.168.0.103:80'; // OTPanelProvider - uses "vocIp" key
  
  // UI animations
  late AnimationController _cardController;
  late Animation<Offset> _cardSlideAnimation;
  late AnimationController _bgController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fumigationBlinkController;
  late Animation<double> _fumigationBlinkAnimation;

  // Date and time
  late Timer _dateTimeTimer;
  DateTime _currentDateTime = DateTime.now();

  final Random _random = Random();
  final List<MedicalParticle> _particles = [];

  // OR Info
  String _otNumber = '';
  String _doctorName = '';
  String _patientName = '';
  String _surgeryName = '';

  // Fumigation state
  int _fumigationState = 0;
  String _fumigationTimer = '--:--';

  bool get _shouldBlinkRed => _fumigationState == 2 || _fumigationState == 3;

  Timer? _fumigationPollTimer;
  bool _isShowingRequestDialog = false;

  // System power relay — same as the home screen's System On/Off
  // (relay 10 is wired as the master on/off; relay 8 is night mode).
  static const int _systemPowerRelay = 10;
  static const int _defumigationRelay = 9;
  static const int _nightModeRelay = 8;

  // Guards against double-taps while a system on/off write is in flight.
  bool _isSystemPowerBusy = false;
  // Relays with a defumigation/night write in flight.
  final Set<int> _busyRelays = {};

  @override
  void initState() {
    super.initState();
    _loadORInfo();

    for (int i = 0; i < 18; i++) {
      _particles.add(MedicalParticle(_random));
    }

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardController, curve: Curves.easeOut));
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fumigationBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fumigationBlinkAnimation = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(
        parent: _fumigationBlinkController,
        curve: Curves.easeInOut,
      ),
    );

    _cardController.forward();
    _dateTimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentDateTime = DateTime.now());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
      _startPolling();
    });
  }

  // Load IPs from SharedPreferences
  Future<void> _loadIPs() async {
    final prefs = await SharedPreferences.getInstance();

    // Load OTPanel IP (pressure/relays) - uses "vocIp" key
    final savedVocIp = prefs.getString("vocIp");
    if (savedVocIp != null && savedVocIp.isNotEmpty) {
      _pressureRelayIP = savedVocIp.contains(':') ? savedVocIp : "$savedVocIp:80";
      print('📍 Loaded OTPanel (Pressure/Relays) IP from "vocIp": $_pressureRelayIP');
    } else {
      print('📍 Using default OTPanel (Pressure/Relays) IP: $_pressureRelayIP');
    }
  }

  // Initialize providers with loaded IPs
  Future<void> _initializeProviders() async {
    await _loadIPs();
    if (!mounted) return;
    // Initialize OTPanelProvider with "vocIp" (pressure/relays)
    final otPanelProvider = Provider.of<OTPanelProvider>(context, listen: false);
    await otPanelProvider.initialize(ipOverride: _pressureRelayIP);
  }

  Future<void> _loadORInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _otNumber = prefs.getString("otNumber") ?? '';
      _doctorName = prefs.getString("doctorName") ?? '';
      _patientName = prefs.getString("patientName") ?? '';
      _surgeryName = prefs.getString("surgeryName") ?? '';
    });
  }

  // Get the OTPanelProvider's base URL (Pressure/Relay controller)
  String get _otPanelBaseUrl {
    final otPanelProvider = Provider.of<OTPanelProvider>(context, listen: false);
    return 'http://${otPanelProvider.esp32IP}:80';
  }

  // ═══════════════════════════════════════════════════════════════
  // POLLING FOR FUMIGATION STATUS (from OTPanel controller)
  // ═══════════════════════════════════════════════════════════════
  void _startPolling() {
    _stopPolling();

    Future.delayed(const Duration(milliseconds: 500), () {
      _fetchFumigationStatus();
    });

    _fumigationPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final otPanelProvider = Provider.of<OTPanelProvider>(context, listen: false);
      // Fumigation lives on the Waveshare only
      if (otPanelProvider.waveshareOnline) _fetchFumigationStatus();
    });
  }

  void _stopPolling() {
    _fumigationPollTimer?.cancel();
    _fumigationPollTimer = null;
  }

  // ═══════════════════════════════════════════════════════════════
  // FUMIGATION STATUS
  // ═══════════════════════════════════════════════════════════════
  Future<void> _fetchFumigationStatus() async {
    try {
      final http.Client client = http.Client();
      final r = await client
          .get(Uri.parse('$_otPanelBaseUrl/api/fumigation/status'))
          .timeout(const Duration(seconds: 5));
      client.close();
      
      if (r.statusCode == 200 && mounted) {
        final d = json.decode(r.body);
        final prevState = _fumigationState;
        setState(() {
          _fumigationState = d['state'] ?? 0;
          if (_shouldBlinkRed) {
            if (!_fumigationBlinkController.isAnimating) {
              _fumigationBlinkController.repeat(reverse: true);
            }
          } else {
            if (_fumigationBlinkController.isAnimating) {
              _fumigationBlinkController.stop();
              _fumigationBlinkController.reset();
            }
          }
          _fumigationTimer = (_fumigationState == 2 || _fumigationState == 3)
              ? _formatTime(d['remaining'] as int? ?? 0)
              : '--:--';
        });
        if (_fumigationState == 1 &&
            prevState != 1 &&
            !_isShowingRequestDialog) {
          _showFumigationRequestDialog();
        }
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  // FUMIGATION ACTIONS (POST to OTPanel controller)
  // ═══════════════════════════════════════════════════════════════
  Future<void> _postFumigation(String path) async {
    try {
      final http.Client client = http.Client();
      final r = await client
          .post(
            Uri.parse('$_otPanelBaseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: '{}',
          )
          .timeout(const Duration(seconds: 5));
      client.close();
      // The controller refuses with a reason, e.g. "PERSON INSIDE OT" (403)
      // or "OCCUPANCY SENSOR OFFLINE/TIMEOUT" (503).
      if (r.statusCode != 200 && mounted) {
        String error = 'Request failed (${r.statusCode})';
        try {
          error = json.decode(r.body)['error'] ?? error;
        } catch (_) {}
        _showSnackBar(error, Colors.red);
      }
      _fetchFumigationStatus();
    } catch (e) {
      if (mounted) _showSnackBar('Connection error', Colors.red);
    }
  }

  // Defumigation (relay 9) and night mode (relay 10) are plain relays,
  // switched the same way as System On/Off.
  Future<void> _handleRelayToggle(
    int relay,
    String label,
    bool turnOn,
    Color onColor,
  ) async {
    if (_busyRelays.contains(relay)) return;
    setState(() => _busyRelays.add(relay));
    try {
      final otPanelProvider = Provider.of<OTPanelProvider>(context, listen: false);
      final ok = await otPanelProvider.setLight(relay, turnOn);
      if (ok) {
        _showSnackBar(
          '$label ${turnOn ? 'ON' : 'OFF'}',
          turnOn ? onColor : Colors.grey,
        );
      } else {
        _showSnackBar(
          'Failed to turn $label ${turnOn ? 'on' : 'off'}',
          Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _busyRelays.remove(relay));
    }
  }

  // Same behaviour as the home screen: confirm before turning the system
  // off, then switch the system power relay.
  Future<void> _handleSystemPowerToggle(bool turnOn) async {
    if (_isSystemPowerBusy) return;

    if (!turnOn) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Confirm"),
          content: const Text("Are you sure you want to turn off the system?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Yes"),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    setState(() => _isSystemPowerBusy = true);
    try {
      final otPanelProvider = Provider.of<OTPanelProvider>(context, listen: false);
      final ok = await otPanelProvider.setLight(_systemPowerRelay, turnOn);
      if (ok) {
        _showSnackBar(
          'System turned ${turnOn ? 'ON' : 'OFF'}',
          turnOn ? Colors.green : Colors.grey,
        );
      } else {
        _showSnackBar(
          'Failed to ${turnOn ? 'start' : 'stop'} system',
          Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isSystemPowerBusy = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UI HELPERS
  // ═══════════════════════════════════════════════════════════════
  void _showSnackBar(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showFumigationRequestDialog() {
    if (_isShowingRequestDialog) return;
    _isShowingRequestDialog = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D27),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.orange.withOpacity(0.5), width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Fumigation Requested',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A fumigation request has been received.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 16),
            Text(
              'Do you want to confirm or reject?',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _isShowingRequestDialog = false;
                    _postFumigation('/api/fumigation/cancel');
                  },
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text('REJECT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _isShowingRequestDialog = false;
                    _postFumigation('/api/fumigation/confirm');
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text('CONFIRM'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).then((_) => _isShowingRequestDialog = false);
  }

  String _formatTime(int s) {
    if (s < 0) s = 0;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  String _formattedDate() =>
      "${_currentDateTime.day.toString().padLeft(2, '0')} ${_monthName(_currentDateTime.month)} ${_currentDateTime.year}";
  String _formattedTime() {
    final h = _currentDateTime.hour > 12
        ? _currentDateTime.hour - 12
        : (_currentDateTime.hour == 0 ? 12 : _currentDateTime.hour);
    return "$h:${_currentDateTime.minute.toString().padLeft(2, '0')} ${_currentDateTime.hour >= 12 ? 'PM' : 'AM'}";
  }

  String _monthName(int m) => const [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ][m - 1];
  
  Color _getPressureColor(double pressure) {
    if (pressure >= 5) return Colors.green;
    if (pressure > 0) return Colors.orange;
    return Colors.red;
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // Temp/humidity, pressure, relays and fumigation all come from the
    // OTPanel controller ("vocIp"), same as the home screen.
    final otPanelProvider = Provider.of<OTPanelProvider>(context);

    final nightModeActive = otPanelProvider.lightStates[_nightModeRelay - 1];
    final systemOn = otPanelProvider.lightStates[_systemPowerRelay - 1];
    final defumigationActive =
        otPanelProvider.lightStates[_defumigationRelay - 1];

    final isConnected = otPanelProvider.isConnected;
    // Temp/RH come from a separate ESP32 ("espIp":8080), not the Waveshare
    final sensorOnline =
        otPanelProvider.secondEspOnline && otPanelProvider.secondEspDataReceived;

    return AnimatedBuilder(
      animation: _fumigationBlinkAnimation,
      builder: (context, child) {
        final bgColor = _shouldBlinkRed
            ? Color.lerp(
                const Color(0xFF1A0000),
                Colors.red.shade900,
                _fumigationBlinkAnimation.value,
              )!
            : const Color(0xFF3D8A8F);

        return Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: [
              AnimatedBuilder(
                animation: _bgController,
                builder: (context, child) => CustomPaint(
                  painter: ClinicalBackgroundPainter(
                    t: _bgController.value,
                    particles: _particles,
                    isBlinking: _shouldBlinkRed,
                    blinkValue: _fumigationBlinkAnimation.value,
                  ),
                  size: Size.infinite,
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmall = constraints.maxHeight < 600;
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.all(isSmall ? 12.0 : 20.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    _logoContainer('assets/image.png', isSmall),
                                    _logoContainer(
                                      'assets/app_logo-removebg-preview.png',
                                      isSmall,
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    _connectionDot(isConnected),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: _startPolling,
                                      icon: const Icon(
                                        Icons.refresh,
                                        color: Colors.white70,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: isSmall ? 10 : 20),
                            if (_shouldBlinkRed) _dangerBanner(isSmall),
                            Text(
                              "Status Monitor",
                              style: TextStyle(
                                fontSize: isSmall ? 20 : 26,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: isSmall ? 8 : 12),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmall ? 12 : 20,
                                vertical: isSmall ? 8 : 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _infoTile(
                                    Icons.meeting_room_outlined,
                                    "OT",
                                    _otNumber,
                                    isSmall,
                                  ),
                                  // _divider(),
                                  // _infoTile(
                                  //   Icons.medical_services_outlined,
                                  //   "Doctor",
                                  //   _doctorName,
                                  //   isSmall,
                                  // ),
                                  // _divider(),
                                  // _infoTile(
                                  //   Icons.person_outline,
                                  //   "Patient",
                                  //   _patientName,
                                  //   isSmall,
                                  // ),
                                  // _divider(),
                                  // _infoTile(
                                  //   Icons.local_hospital_outlined,
                                  //   "Surgery",
                                  //   _surgeryName,
                                  //   isSmall,
                                  // ),
                                ],
                              ),
                            ),
                            SizedBox(height: isSmall ? 10 : 16),
                            Flexible(
                              child: SlideTransition(
                                position: _cardSlideAnimation,
                                child: Container(
                                  padding: EdgeInsets.all(isSmall ? 12 : 20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _sensorTile(
                                              "Temperature",
                                              otPanelProvider.temperature.toStringAsFixed(1),
                                              "°C",
                                              Icons.thermostat_outlined,
                                              isSmall,
                                              !sensorOnline,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _sensorTile(
                                              "R/H",
                                              otPanelProvider.humidity.toStringAsFixed(1),
                                              "%",
                                              Icons.water_drop_outlined,
                                              isSmall,
                                              !sensorOnline,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _pressureTile(
                                              otPanelProvider.pressurePa,
                                              isSmall,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: isSmall ? 4 : 6),
                                      CustomPaint(
                                        size: Size(
                                          constraints.maxWidth,
                                          isSmall ? 20 : 34,
                                        ),
                                        painter: SimpleSeparatorPainter(),
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _sensorTile(
                                              "Time",
                                              _formattedTime(),
                                              null,
                                              Icons.access_time_outlined,
                                              isSmall,
                                              false,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _sensorTile(
                                              "Date",
                                              _formattedDate(),
                                              null,
                                              Icons.calendar_today_outlined,
                                              isSmall,
                                              false,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_shouldBlinkRed) ...[
                                        SizedBox(height: isSmall ? 4 : 6),
                                        CustomPaint(
                                          size: Size(
                                            constraints.maxWidth,
                                            isSmall ? 20 : 34,
                                          ),
                                          painter: SimpleSeparatorPainter(),
                                        ),
                                        _sensorTile(
                                          "Fumigation Timer",
                                          _fumigationTimer,
                                          null,
                                          Icons.timer,
                                          isSmall,
                                          false,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: isSmall ? 12 : 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _toggleBtn(
                                  "Defumigation",
                                  defumigationActive,
                                  Icons.science_outlined,
                                  Colors.orange,
                                  (v) => _handleRelayToggle(
                                    _defumigationRelay,
                                    'Defumigation',
                                    v,
                                    Colors.orange,
                                  ),
                                  isSmall,
                                ),
                                _toggleBtn(
                                  "Night",
                                  nightModeActive,
                                  Icons.mode_night_outlined,
                                  Colors.indigo,
                                  (v) => _handleRelayToggle(
                                    _nightModeRelay,
                                    'Night mode',
                                    v,
                                    Colors.indigo,
                                  ),
                                  isSmall,
                                ),
                                _toggleBtn(
                                  "System On/Off",
                                  systemOn,
                                  Icons.power_settings_new,
                                  Colors.green,
                                  _handleSystemPowerToggle,
                                  isSmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _logoContainer(String asset, bool isSmall) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        height: isSmall ? 70 : 100,
        width: isSmall ? 150 : 200,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Center(child: Image.asset(asset, height: isSmall ? 50 : 70)),
      ),
    ),
  );

  Widget _connectionDot(bool isConnected) {
    final c = isConnected ? Colors.green : Colors.redAccent;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Icon(
          isConnected ? Icons.wifi : Icons.signal_wifi_off,
          color: c,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          isConnected ? "Connected" : "Disconnected",
          style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _dangerBanner(bool isSmall) => Padding(
    padding: EdgeInsets.only(bottom: isSmall ? 6 : 12),
    child: Container(
      padding: EdgeInsets.all(isSmall ? 10 : 16),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(
          0.3 * _fumigationBlinkAnimation.value,
        ),
        borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
        border: Border.all(
          color: Colors.red.withOpacity(0.8 * _fumigationBlinkAnimation.value),
          width: isSmall ? 2 : 3,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _fumigationState == 2 ? Icons.timer_off : Icons.dangerous,
            color: Colors.red.shade200,
            size: isSmall ? 28 : 38,
          ),
          SizedBox(height: isSmall ? 6 : 10),
          Text(
            _fumigationState == 2
                ? 'COUNTDOWN IN PROGRESS'
                : 'DANGER - FUMIGATION ACTIVE',
            style: TextStyle(
              color: Colors.red.shade200,
              fontWeight: FontWeight.w900,
              fontSize: isSmall ? 14 : 18,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            _fumigationState == 2 ? 'EVACUATE IMMEDIATELY' : 'DO NOT ENTER',
            style: TextStyle(
              color: Colors.red.shade300,
              fontWeight: FontWeight.bold,
              fontSize: isSmall ? 10 : 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _infoTile(IconData ic, String label, String val, bool sm) => Expanded(
    child: Row(
      children: [
        Icon(ic, color: Colors.cyanAccent, size: sm ? 26 : 30),
        SizedBox(width: sm ? 4 : 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
             
              Text(
                val.isEmpty ? '-' : val,
                style: TextStyle(
                  fontSize: sm ? 22 : 25,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _divider() => Container(
    height: 36,
    width: 1,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: Colors.white.withOpacity(0.18),
  );

  Widget _pressureTile(double pressure, bool sm) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnimation.value,
              child: const Icon(
                Icons.compress_outlined,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "Room Pressure",
            style: TextStyle(fontSize: sm ? 12 : 14, color: Colors.white70),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          _AnimatedCounter(
            value: pressure.toStringAsFixed(2),
            isSmall: sm,
            color: _getPressureColor(pressure),
          ),
          const SizedBox(width: 4),
          Text(
            "Pa",
            style: TextStyle(
              fontSize: sm ? 14 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _sensorTile(
    String title,
    String value,
    String? unit,
    IconData icon,
    bool sm,
    bool dim,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Icon(
                icon,
                color: dim ? Colors.white30 : Colors.white70,
                size: sm ? 18 : 22,
              ),
            ),
          ),
          SizedBox(width: sm ? 4 : 8),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: sm ? 12 : 14,
                color: dim ? Colors.white30 : Colors.white70,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      SizedBox(height: sm ? 3 : 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (title == "Date" || title == "Time" || title == "Fumigation Timer")
            Text(
              value,
              style: TextStyle(
                fontSize: sm ? 22 : 30,
                fontWeight: FontWeight.bold,
                color: dim ? Colors.white30 : Colors.white,
              ),
            )
          else
            _AnimatedCounter(
              value: value,
              isSmall: sm,
              color: dim ? Colors.white30 : Colors.white,
            ),
          if (unit != null)
            Padding(
              padding: EdgeInsets.only(left: sm ? 4 : 6),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: sm ? 14 : 18,
                  fontWeight: FontWeight.bold,
                  color: dim ? Colors.white30 : Colors.white,
                ),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _toggleBtn(
    String label,
    bool val,
    IconData icon,
    Color activeColor,
    Function(bool) cb,
    bool sm,
  ) => Flexible(
    child: Column(
      children: [
        Icon(icon, color: val ? activeColor : Colors.white, size: sm ? 22 : 28),
        SizedBox(height: sm ? 3 : 6),
        Text(
          label,
          style: TextStyle(color: Colors.white, fontSize: sm ? 11 : 13),
        ),
        SizedBox(height: sm ? 4 : 8),
        GestureDetector(
          onTap: () => cb(!val),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            width: sm ? 44 : 56,
            height: sm ? 24 : 30,
            padding: EdgeInsets.all(sm ? 2 : 3),
            decoration: BoxDecoration(
              color: val ? activeColor : Colors.white24,
              borderRadius: BorderRadius.circular(sm ? 12 : 15),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              alignment: val ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: sm ? 20 : 24,
                height: sm ? 20 : 24,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _stopPolling();
    _cardController.dispose();
    _bgController.dispose();
    _pulseController.dispose();
    _fumigationBlinkController.dispose();
    _dateTimeTimer.cancel();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// ANIMATED COUNTER
// ═══════════════════════════════════════════════════════════════
class _AnimatedCounter extends StatefulWidget {
  final String value;
  final bool isSmall;
  final Color color;
  const _AnimatedCounter({
    required this.value,
    this.isSmall = false,
    this.color = Colors.white,
  });
  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  String _cur = "0";

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _update();
  }

  @override
  void didUpdateWidget(_AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _update();
  }

  void _update() {
    final s = double.tryParse(_cur) ?? 0;
    final e = double.tryParse(widget.value) ?? 0;
    _anim = Tween<double>(
      begin: s,
      end: e,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) {
      final v = _anim.value;
      final dec = (v != v.truncateToDouble()) || widget.value.contains('.');
      _cur = dec ? v.toStringAsFixed(2) : v.toInt().toString();
      return Text(
        _cur,
        style: TextStyle(
          fontSize: widget.isSmall ? 22 : 30,
          fontWeight: FontWeight.bold,
          color: widget.color,
        ),
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════════
// PAINTERS
// ═══════════════════════════════════════════════════════════════
class SimpleSeparatorPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) => c.drawLine(
    Offset(0, s.height / 2),
    Offset(s.width, s.height / 2),
    Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..strokeWidth = 1,
  );
  @override
  bool shouldRepaint(covariant SimpleSeparatorPainter o) => false;
}

class MedicalParticle {
  double x, y, size, vx, vy, opacity;
  final Random _r;
  MedicalParticle(this._r)
    : x = _r.nextDouble(),
      y = _r.nextDouble(),
      size = _r.nextDouble() * 2 + 0.6,
      vx = _r.nextDouble() * 0.0008 - 0.0004,
      vy = _r.nextDouble() * 0.0008 - 0.0004,
      opacity = 0.06 + _r.nextDouble() * 0.06;
  void update(double t) {
    x += vx + 0.0002 * sin(t * 2 * pi + x * 10);
    y += vy + 0.0002 * cos(t * 2 * pi + y * 10);
    if (x < -0.02) x = 1.02;
    if (x > 1.02) x = -0.02;
    if (y < -0.02) y = 1.02;
    if (y > 1.02) y = -0.02;
  }
}

class ClinicalBackgroundPainter extends CustomPainter {
  final double t;
  final List<MedicalParticle> particles;
  final bool isBlinking;
  final double blinkValue;
  ClinicalBackgroundPainter({
    required this.t,
    required this.particles,
    this.isBlinking = false,
    this.blinkValue = 0.0,
  });

  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    final gT = (sin(t * 2 * pi) + 1) / 2 * 0.2;
    Color c1 = Color.lerp(
      const Color(0xFF0F3D3E),
      const Color(0xFF2C6975),
      gT,
    )!;
    Color c2 = Color.lerp(
      const Color(0xFF144552),
      const Color(0xFF205375),
      gT,
    )!;
    Color c3 = Color.lerp(
      const Color(0xFF16324F),
      const Color(0xFF112031),
      gT,
    )!;
    if (isBlinking) {
      c1 = Color.lerp(
        const Color(0xFF1A0000),
        Colors.red.shade900,
        blinkValue,
      )!;
      c2 = Color.lerp(
        const Color(0xFF200000),
        Colors.red.shade800,
        blinkValue,
      )!;
      c3 = Color.lerp(
        const Color(0xFF1A0000),
        Colors.red.shade900,
        blinkValue,
      )!;
    }
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2, c3],
        ).createShader(rect),
    );
    final gp = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 0.5;
    for (double x = 0; x < s.width; x += 40)
      c.drawLine(Offset(x, 0), Offset(x, s.height), gp);
    for (double y = 0; y < s.height; y += 40)
      c.drawLine(Offset(0, y), Offset(s.width, y), gp);
    final dp = Paint()..style = PaintingStyle.fill;
    for (var p in particles) {
      p.update(t);
      dp.color = Colors.white.withOpacity(p.opacity);
      c.drawCircle(Offset(p.x * s.width, p.y * s.height), p.size, dp);
    }
  }

  @override
  bool shouldRepaint(covariant ClinicalBackgroundPainter o) => true;
}