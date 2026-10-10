import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:wiespl_surgeon_panel/services/nnn.dart'; // Update this import path as needed
import 'package:wiespl_surgeon_panel/widgets/gauge_arc_hit.dart';

class TempGaugeScreen extends StatefulWidget {
  const TempGaugeScreen({super.key});

  @override
  State<TempGaugeScreen> createState() => _TempGaugeScreenState();
}

class _TempGaugeScreenState extends State<TempGaugeScreen> {
  bool _isSettingValue = false;
  DateTime? _lastSetTime;
  static const Duration _minSetInterval = Duration(seconds: 2);

  static const double _minTemperature = 16.0;
  static const double _maxTemperature = 24.0; // FIXED: was 28.0

  // Local unconfirmed gauge value
  double _pendingTemperature = _minTemperature;

  // Provider reference for listener-based sync with PLC / SharedPreferences
  OTPanelProvider? _provider;

  // Track pending async operations so we can cancel them on dispose
  bool _disposed = false;

  // True while a drag that started on the gauge bar is in progress
  bool _gaugeGrabbed = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = Provider.of<OTPanelProvider>(context, listen: false);
    if (!identical(p, _provider)) {
      _provider?.removeListener(_onProviderChanged);
      _provider = p;
      _provider!.addListener(_onProviderChanged);
      // Sync immediately with whatever the provider currently has
      _onProviderChanged();
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    _disposed = true;
    super.dispose();
  }

  /// Called whenever OTPanelProvider calls notifyListeners().
  /// This is what makes the gauge react to PLC-side setpoint changes
  /// and to values loaded back from SharedPreferences.
  void _onProviderChanged() {
    if (_disposed || !mounted || _isSettingValue) return;

    final remote = _provider!.temperatureSetpoint;
    if (remote < _minTemperature || remote > _maxTemperature) return;

    // Only override the local pending value if it actually differs,
    // so we don't fight with the user's in-progress drag.
    if ((remote - _pendingTemperature).abs() >= 0.5) {
      setState(() {
        _pendingTemperature = remote;
      });
    }
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_disposed || !mounted) return;

      final otPanelProvider = Provider.of<OTPanelProvider>(
        context,
        listen: false,
      );

      // This should load persisted value from SharedPreferences AND
      // fetch the current setpoint from the PLC.
      await otPanelProvider.refreshData();

      if (_disposed || !mounted) return;

      // After refresh, sync our local pending value from the provider.
      // The listener added in didChangeDependencies will also fire,
      // but doing it explicitly here covers the case where the value
      // didn't change (so notifyListeners might not fire).
      final double initialTemp = otPanelProvider.temperatureSetpoint;
      setState(() {
        if (initialTemp >= _minTemperature &&
            initialTemp <= _maxTemperature) {
          _pendingTemperature = initialTemp;
        } else {
          _pendingTemperature = _minTemperature;
        }
      });
    });
  }

  void _handleGaugeInteraction(Offset localPosition, Size gaugeSize) {
    final fraction = GaugeArcHit.fraction(localPosition, gaugeSize);
    double value =
        _minTemperature + (fraction * (_maxTemperature - _minTemperature));
    value = value.roundToDouble().clamp(_minTemperature, _maxTemperature);

    setState(() {
      _pendingTemperature = value;
    });
  }

  Future<void> _setTemperature() async {
    if (_isSettingValue || _disposed || !mounted) return;

    final otPanelProvider = Provider.of<OTPanelProvider>(
      context,
      listen: false,
    );

    if (!otPanelProvider.secondEspOnline) {
      Get.snackbar(
        "Error",
        "ESP not connected",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final now = DateTime.now();
    if (_lastSetTime != null &&
        now.difference(_lastSetTime!) < _minSetInterval) {
      return;
    }

    // Capture the value before any await — provider state can change
    final double temperatureToSet = _pendingTemperature;
    final int sentValue = (temperatureToSet * 10).round();

    if (sentValue < 160 || sentValue > 240) {
      Get.snackbar(
        "Error",
        "Value must be between 16.0°C and 24.0°C.",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (mounted) setState(() => _isSettingValue = true);

    try {
      print("🎯 Sending $sentValue to ESP32...");
      _lastSetTime = DateTime.now();

      final ok = await otPanelProvider.setTemperatureSetpoint(
        temperatureToSet,
      );

      // Check again after await — widget may have been disposed during the call
      if (_disposed || !mounted) return;

      if (!ok) {
        Get.snackbar(
          "Set Failed",
          "ESP32 did not accept the new temperature setpoint",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      Get.snackbar(
        "Success",
        "Temperature set to ${temperatureToSet.toStringAsFixed(0)}°C",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      // Pop immediately — no delay. The snackbar shows on the previous screen.
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print("❌ Error: $e");
      if (!_disposed && mounted) {
        Get.snackbar(
          "Set Failed",
          e.toString(),
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } finally {
      if (!_disposed && mounted) setState(() => _isSettingValue = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 35, 87, 136),
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF235788), Color(0xC15F8BB8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Consumer<OTPanelProvider>(
              builder: (context, otPanelProvider, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(otPanelProvider),
                    const SizedBox(height: 20),
                    _buildInfoPanel(otPanelProvider),
                    const SizedBox(height: 10),
                    _buildGauge(otPanelProvider),
                    const SizedBox(height: 30),
                    _buildActionButtons(otPanelProvider),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(OTPanelProvider otPanelProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(
          Icons.circle,
          color: otPanelProvider.secondEspOnline ? Colors.green : Colors.red,
          size: 12,
        ),
        const Text(
          "Temperature Control",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildInfoPanel(OTPanelProvider otPanelProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _infoColumn(
            "Current",
            "${otPanelProvider.temperature.toStringAsFixed(1)}°C",
            Colors.white,
          ),
          Container(width: 1, height: 30, color: Colors.white30),
          _infoColumn(
            "Setpoint",
            "${otPanelProvider.temperatureSetpoint.toStringAsFixed(0)}°C",
            Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _infoColumn(String label, String value, Color valColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valColor,
          ),
        ),
      ],
    );
  }

  Widget _buildGauge(OTPanelProvider otPanelProvider) {
    return SizedBox(
      height: 250,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          // Only touches on the bar count; a drag must start on the bar but
          // may then wander off it.
          return GestureDetector(
            onTapDown: (details) {
              if (GaugeArcHit.isOnArc(details.localPosition, size)) {
                _handleGaugeInteraction(details.localPosition, size);
              }
            },
            onPanStart: (details) {
              _gaugeGrabbed = GaugeArcHit.isOnArc(details.localPosition, size);
              if (_gaugeGrabbed) {
                _handleGaugeInteraction(details.localPosition, size);
              }
            },
            onPanUpdate: (details) {
              if (_gaugeGrabbed) {
                _handleGaugeInteraction(details.localPosition, size);
              }
            },
            onPanEnd: (_) => _gaugeGrabbed = false,
            onPanCancel: () => _gaugeGrabbed = false,
            child: SfRadialGauge(
              axes: [
                RadialAxis(
                  minimum: _minTemperature,
                  maximum: _maxTemperature,
                  startAngle: 150,
                  endAngle: 30,
                  showTicks: false,
                  showLabels: false,
                  axisLineStyle: const AxisLineStyle(
                    thickness: 0.15,
                    thicknessUnit: GaugeSizeUnit.factor,
                    color: Colors.white24,
                    cornerStyle: CornerStyle.bothCurve,
                  ),
                  pointers: [
                    RangePointer(
                      value: _pendingTemperature,
                      width: 0.15,
                      color: Colors.white,
                      cornerStyle: CornerStyle.bothCurve,
                      sizeUnit: GaugeSizeUnit.factor,
                    ),
                    MarkerPointer(
                      value: _pendingTemperature,
                      markerType: MarkerType.circle,
                      color: Colors.white,
                      markerHeight: 20,
                      markerWidth: 20,
                      borderColor: const Color(0xFF3D8A8F),
                      borderWidth: 3,
                    ),
                  ],
                  annotations: [
                    GaugeAnnotation(
                      angle: 90,
                      positionFactor: 0,
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _pendingTemperature.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            "°C",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(OTPanelProvider otPanelProvider) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: otPanelProvider.secondEspOnline && !_isSettingValue
                ? _setTemperature
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: otPanelProvider.secondEspOnline
                  ? Colors.black
                  : Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              otPanelProvider.secondEspOnline ? "SET TEMPERATURE" : "DISCONNECTED",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("BACK", style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}