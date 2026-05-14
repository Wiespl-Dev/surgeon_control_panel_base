import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:wiespl_surgeon_panel/services/esptwo.dart';

class TempGaugeScreen extends StatefulWidget {
  const TempGaugeScreen({super.key});

  @override
  State<TempGaugeScreen> createState() => _TempGaugeScreenState();
}

class _TempGaugeScreenState extends State<TempGaugeScreen> {
  bool _isSettingValue = false;
  DateTime? _lastSetTime;
  static const Duration _minSetInterval = Duration(seconds: 2);

  // Safe bounds as per your ESP32 configuration
  static const double _minTemperature = 18.0;
  static const double _maxTemperature = 28.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final espProvider = Provider.of<ESP32Provider>(context, listen: false);

      // 1. Request status from hardware immediately
      espProvider.requestTemperatureStatus();

      // 2. Wait for a heartbeat/response before syncing the UI gauge
      // We use a slightly longer delay to ensure the provider has updated its variables
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          final provider = Provider.of<ESP32Provider>(context, listen: false);
          double initialTemp = provider.temperatureSetpointAsDouble;

          // CRITICAL: Only update the gauge if we got a valid non-zero value.
          // If initialTemp is 0.0, the ESP hasn't responded yet; don't sync it.
          if (initialTemp >= _minTemperature &&
              initialTemp <= _maxTemperature) {
            provider.updatePendingTemperature(initialTemp);
          } else {
            // Fallback to safe default for the UI only, doesn't send to ESP
            provider.updatePendingTemperature(_minTemperature);
          }
        }
      });
    });
  }

  void _handleGaugeInteraction(Offset localPosition, Size gaugeSize) {
    final center = gaugeSize.center(Offset.zero);
    final angle = (localPosition - center).direction;

    double startAngleRad = 150 * (math.pi / 180);
    double endAngleRad = 30 * (math.pi / 180);

    double normalizedAngle = angle;
    if (normalizedAngle < startAngleRad) {
      normalizedAngle += 2 * math.pi;
    }

    double percentage =
        (normalizedAngle - startAngleRad) /
        (endAngleRad - startAngleRad + 2 * math.pi);

    double value =
        _minTemperature + (percentage * (_maxTemperature - _minTemperature));
    value = value.roundToDouble().clamp(_minTemperature, _maxTemperature);

    final espProvider = Provider.of<ESP32Provider>(context, listen: false);
    espProvider.updatePendingTemperature(value);
  }

  Future<void> _setTemperature() async {
    final espProvider = Provider.of<ESP32Provider>(context, listen: false);

    if (_isSettingValue) return;

    if (!espProvider.isConnected) {
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

    setState(() => _isSettingValue = true);

    try {
      final temperatureToSet = espProvider.pendingTemperature;
      final int sentValue = (temperatureToSet * 10).round();

      // EXTRA SAFETY: If for some reason the value is 0 or extremely low,
      // abort to prevent hardware shutdown.
      if (sentValue < 180) {
        throw Exception('Value $sentValue is unsafe. Minimum is 180 (18.0°C).');
      }

      print("🎯 Sending $sentValue to ESP32...");
      _lastSetTime = DateTime.now();

      await espProvider.setTemperature(temperatureToSet);

      Get.snackbar(
        "Success",
        "Temperature set to ${temperatureToSet.toStringAsFixed(0)}°C",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print("❌ Error: $e");
      Get.snackbar(
        "Set Failed",
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isSettingValue = false);
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
            child: Consumer<ESP32Provider>(
              builder: (context, espProvider, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(espProvider),
                    const SizedBox(height: 20),
                    _buildInfoPanel(espProvider),
                    const SizedBox(height: 10),
                    _buildGauge(espProvider),
                    const SizedBox(height: 30),
                    _buildActionButtons(espProvider),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ESP32Provider espProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(
          Icons.circle,
          color: espProvider.isConnected ? Colors.green : Colors.red,
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

  Widget _buildInfoPanel(ESP32Provider espProvider) {
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
            "${espProvider.currentTemperature}°C",
            Colors.white,
          ),
          Container(width: 1, height: 30, color: Colors.white30),
          _infoColumn(
            "Setpoint",
            "${espProvider.temperatureSetpointAsDouble.toStringAsFixed(0)}°C",
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

  Widget _buildGauge(ESP32Provider espProvider) {
    return SizedBox(
      height: 250,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onPanUpdate: (details) => _handleInteraction(
              context,
              details.globalPosition,
              constraints,
            ),
            onTapDown: (details) => _handleInteraction(
              context,
              details.globalPosition,
              constraints,
            ),
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
                      value: espProvider.pendingTemperature,
                      width: 0.15,
                      color: Colors.white,
                      cornerStyle: CornerStyle.bothCurve,
                      sizeUnit: GaugeSizeUnit.factor,
                    ),
                    MarkerPointer(
                      value: espProvider.pendingTemperature,
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
                            espProvider.pendingTemperature.toStringAsFixed(0),
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

  void _handleInteraction(
    BuildContext context,
    Offset globalPos,
    BoxConstraints constraints,
  ) {
    final box = context.findRenderObject() as RenderBox;
    final localPos = box.globalToLocal(globalPos);
    _handleGaugeInteraction(localPos, constraints.biggest);
  }

  Widget _buildActionButtons(ESP32Provider espProvider) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: espProvider.isConnected && !_isSettingValue
                ? _setTemperature
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSettingValue
                  ? Colors.blue
                  : (espProvider.isConnected ? Colors.black : Colors.grey),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: _isSettingValue
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    espProvider.isConnected
                        ? "SET TEMPERATURE"
                        : "DISCONNECTED",
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
