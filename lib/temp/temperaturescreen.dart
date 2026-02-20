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
  int _setAttemptCount = 0;

  // Temperature range configuration
  static const double _minTemperature = 15.0;
  static const double _maxTemperature = 25.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final espProvider = Provider.of<ESP32Provider>(context, listen: false);
      // Initialize with current setpoint from ESP32
      espProvider.requestTemperatureStatus();

      // After a short delay, sync pending temperature with actual setpoint
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          final provider = Provider.of<ESP32Provider>(context, listen: false);
          // Initialize pending temperature with current setpoint
          provider.updatePendingTemperature(
            provider.temperatureSetpointAsDouble,
          );
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

    // Calculate percentage based on angle (0 to 1)
    double percentage =
        (normalizedAngle - startAngleRad) /
        (endAngleRad - startAngleRad + 2 * math.pi);

    // Map percentage to our range (15-25) and round to nearest whole number
    double value =
        _minTemperature + (percentage * (_maxTemperature - _minTemperature));

    // Round to nearest whole number
    value = value.roundToDouble();

    // Clamp to ensure within bounds
    value = value.clamp(_minTemperature, _maxTemperature);

    final espProvider = Provider.of<ESP32Provider>(context, listen: false);
    espProvider.updatePendingTemperature(value);
  }

  Future<void> _setTemperature() async {
    final espProvider = Provider.of<ESP32Provider>(context, listen: false);

    if (_isSettingValue) {
      print("⏳ Already setting temperature, please wait");
      return;
    }

    if (!espProvider.isConnected) {
      Get.snackbar(
        "Error",
        "ESP not connected",
        snackPosition: SnackPosition.TOP,
        colorText: Colors.white,
        backgroundColor: Colors.red,
      );
      return;
    }

    final now = DateTime.now();
    if (_lastSetTime != null &&
        now.difference(_lastSetTime!) < _minSetInterval) {
      print("⏳ Please wait before setting again");
      Get.snackbar(
        "Please Wait",
        "Wait a moment before setting again",
        snackPosition: SnackPosition.TOP,
        colorText: Colors.white,
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 1),
      );
      return;
    }

    setState(() {
      _isSettingValue = true;
      _setAttemptCount++;
    });

    try {
      final temperatureToSet = espProvider.pendingTemperature;
      print(
        "🎯 Setting temperature to: ${temperatureToSet.toStringAsFixed(0)}°C",
      );

      _lastSetTime = DateTime.now();

      // Send temperature command to ESP - THIS IS WHERE THE VALUE IS SAVED/SET
      await espProvider.setTemperature(temperatureToSet);

      Get.snackbar(
        "Success",
        "Temperature set to ${temperatureToSet.toStringAsFixed(0)}°C",
        snackPosition: SnackPosition.TOP,
        colorText: Colors.white,
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );

      await Future.delayed(const Duration(milliseconds: 1800));

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print("❌ Error setting temperature: $e");
      Get.snackbar(
        "Set Failed",
        "Failed to set temperature: ${e.toString().split('\n').first}",
        snackPosition: SnackPosition.TOP,
        colorText: Colors.white,
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.error, color: Colors.white),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSettingValue = false;
        });
      }
    }
  }

  Color _getButtonColor(ESP32Provider espProvider) {
    if (!espProvider.isConnected) return Colors.grey;
    if (_isSettingValue) return Colors.blue;
    return Colors.black;
  }

  Widget _buildButtonContent(ESP32Provider espProvider) {
    if (_isSettingValue) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            "SETTING...",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    return Text(
      espProvider.isConnected ? "SET TEMPERATURE" : "ESP DISCONNECTED",
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
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
                colors: [
                  const Color.fromARGB(255, 35, 87, 136),
                  Color.fromARGB(193, 95, 139, 184),
                ],
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
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ESP Status Indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 1,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: espProvider.isConnected
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: espProvider.isConnected
                                  ? Colors.green
                                  : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [],
                          ),
                        ),

                        // Title
                        const Text(
                          "Temperature Control",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        // Close Button
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 24,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Current and Setpoint Display
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text(
                                "Current",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${espProvider.currentTemperature}°C",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.white30,
                          ),
                          Column(
                            children: [
                              const Text(
                                "Setpoint",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${espProvider.temperatureSetpointAsDouble.toStringAsFixed(0)}°C",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Gauge
                    SizedBox(
                      height: 250,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onPanUpdate: (details) {
                              final box =
                                  context.findRenderObject() as RenderBox;
                              final localPosition = box.globalToLocal(
                                details.globalPosition,
                              );
                              _handleGaugeInteraction(
                                localPosition,
                                constraints.biggest,
                              );
                            },
                            onTapDown: (details) {
                              final box =
                                  context.findRenderObject() as RenderBox;
                              final localPosition = box.globalToLocal(
                                details.globalPosition,
                              );
                              _handleGaugeInteraction(
                                localPosition,
                                constraints.biggest,
                              );
                            },
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
                                    // Optional: Add a marker for current setpoint
                                    if (espProvider
                                            .temperatureSetpointAsDouble !=
                                        espProvider.pendingTemperature)
                                      MarkerPointer(
                                        value: espProvider
                                            .temperatureSetpointAsDouble,
                                        markerType: MarkerType.circle,
                                        color: Colors.amber,
                                        markerHeight: 12,
                                        markerWidth: 12,
                                        borderColor: Colors.white,
                                        borderWidth: 2,
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
                                            espProvider.pendingTemperature
                                                .toStringAsFixed(0),
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
                    ),

                    const SizedBox(height: 30),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: ElevatedButton(
                          onPressed: espProvider.isConnected && !_isSettingValue
                              ? _setTemperature
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getButtonColor(espProvider),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 4,
                          ),
                          child: _buildButtonContent(espProvider),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 16.0,
                            left: 10,
                            top: 8,
                          ),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              "BACK",
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
