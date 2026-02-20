import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:wiespl_surgeon_panel/services/esptwo.dart'; // Update this import path as needed

class HumidityGaugeScreen extends StatefulWidget {
  const HumidityGaugeScreen({super.key});

  @override
  State<HumidityGaugeScreen> createState() => _HumidityGaugeScreenState();
}

class _HumidityGaugeScreenState extends State<HumidityGaugeScreen> {
  bool _isSettingValue = false;
  bool _isDragging = false;
  DateTime? _lastSetTime;
  static const Duration _minSetInterval = Duration(seconds: 2);

  // Local pending humidity (separate from provider to allow dragging)
  double _pendingHumidity = 50.0;

  // Humidity range configuration
  static const double _minHumidity = 45.0;
  static const double _maxHumidity = 55.0;
  static const double _stepSize = 0.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() {
    final esp32Provider = Provider.of<ESP32Provider>(context, listen: false);

    // Start polling if not already started
    esp32Provider.startPolling();

    // Initialize pending humidity from ESP32's setpoint if available
    double initialHumidity = _convertFromSetpointFormat(
      esp32Provider.humiditySetpoint,
    );

    // Clamp to our range and round to nearest 0.5
    initialHumidity = _clampAndRoundToStep(initialHumidity);

    setState(() {
      _pendingHumidity = initialHumidity;
    });

    // Request initial data
    esp32Provider.refreshData();
  }

  // Convert from "500" format (50.0%) to double
  double _convertFromSetpointFormat(String setpoint) {
    if (setpoint.length >= 2) {
      try {
        int value = int.parse(setpoint);
        return value / 10.0;
      } catch (e) {
        return 50.0;
      }
    }
    return 50.0;
  }

  // Convert to "500" format (50.5% -> 505)
  String _convertToSetpointFormat(double value) {
    // Ensure value is rounded to 0.5 increments first
    value = _roundToStep(value);

    // 50.5 -> 505, 50.0 -> 500
    int setpointValue = (value * 10).round();
    return setpointValue.toString().padLeft(3, '0');
  }

  // Clamp value to range and round to nearest 0.5
  double _clampAndRoundToStep(double value) {
    value = value.clamp(_minHumidity, _maxHumidity);
    return _roundToStep(value);
  }

  // Round to nearest 0.5 increment
  double _roundToStep(double value) {
    return (value * 2).round() / 2.0;
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

    // Map percentage to our range (40-60)
    double value = _minHumidity + (percentage * (_maxHumidity - _minHumidity));

    // Round to nearest 0.5 increment
    value = _roundToStep(value);

    // Clamp to ensure within bounds
    value = value.clamp(_minHumidity, _maxHumidity);

    setState(() {
      _pendingHumidity = value;
      _isDragging = true; // User is actively dragging
    });
  }

  Future<void> _setHumidity() async {
    final esp32Provider = Provider.of<ESP32Provider>(context, listen: false);

    if (_isSettingValue) {
      print("⏳ Already setting humidity, please wait");
      return;
    }

    if (!esp32Provider.isConnected) {
      Get.snackbar(
        "Error",
        "ESP32 not connected",
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
    });

    try {
      print("🎯 Setting humidity to: ${_pendingHumidity.toStringAsFixed(1)}%");

      _lastSetTime = DateTime.now();

      // Send humidity setpoint to ESP32
      String humiditySetpoint = _convertToSetpointFormat(_pendingHumidity);

      // Use the provider's sendControl method
      await esp32Provider.sendControl("S_RH_SETPT", humiditySetpoint);

      Get.snackbar(
        "Success",
        "Humidity set to ${_pendingHumidity.toStringAsFixed(1)}%",
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
      print("❌ Error setting humidity: $e");
      Get.snackbar(
        "Set Failed",
        "Failed to set humidity: ${e.toString().split('\n').first}",
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
          _isDragging = false;
        });
      }
    }
  }

  // Get current humidity value from ESP32
  String _getCurrentHumidityValue() {
    final esp32Provider = Provider.of<ESP32Provider>(context);
    return "${esp32Provider.currentHumidity}%";
  }

  Color _getButtonColor(ESP32Provider esp32Provider) {
    if (!esp32Provider.isConnected) return Colors.grey;
    if (_isSettingValue) return Colors.blue;
    return Colors.black;
  }

  Widget _buildButtonContent(ESP32Provider esp32Provider) {
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
      esp32Provider.isConnected ? "SET HUMIDITY" : "ESP32 DISCONNECTED",
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildConnectionStatus() {
    final esp32Provider = Provider.of<ESP32Provider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: BoxDecoration(
        color: esp32Provider.isConnected
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esp32Provider.isConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // const SizedBox(width: 6),
          Text(
            esp32Provider.isConnected ? "" : "",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: esp32Provider.isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 35, 87, 136),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight;
              final isSmallScreen = availableHeight < 600;

              return Center(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: IntrinsicHeight(
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
                                builder: (context, esp32Provider, child) {
                                  // Only update pending humidity from ESP32 if user is not dragging
                                  if (!_isDragging && !_isSettingValue) {
                                    double currentSetpoint =
                                        _convertFromSetpointFormat(
                                          esp32Provider.humiditySetpoint,
                                        );

                                    // If the setpoint from ESP32 is different from our pending humidity
                                    if ((currentSetpoint - _pendingHumidity)
                                            .abs() >
                                        0.1) {
                                      // Only update if the setpoint is within our range
                                      if (currentSetpoint >= _minHumidity &&
                                          currentSetpoint <= _maxHumidity) {
                                        _pendingHumidity = currentSetpoint;
                                      }
                                    }
                                  }

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Header - Fixed height
                                      SizedBox(
                                        height: isSmallScreen ? 40 : 50,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Connection Status Indicator
                                            _buildConnectionStatus(),

                                            // Title
                                            Text(
                                              "Humidity Control",
                                              style: TextStyle(
                                                fontSize: isSmallScreen
                                                    ? 16
                                                    : 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),

                                            // Close Button
                                            IconButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              icon: const Icon(
                                                Icons.close,
                                                color: Colors.white70,
                                                size: 24,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
                                        ),
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
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
                                                  _getCurrentHumidityValue(),
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
                                                  "${_pendingHumidity.toStringAsFixed(1)}%",
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

                                      const SizedBox(height: 20),

                                      // Gauge with flexible height
                                      Flexible(
                                        child: Container(
                                          height: isSmallScreen ? 180 : 220,
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              return GestureDetector(
                                                onPanStart: (details) {
                                                  setState(() {
                                                    _isDragging = true;
                                                  });
                                                },
                                                onPanUpdate: (details) {
                                                  final box =
                                                      context.findRenderObject()
                                                          as RenderBox;
                                                  final localPosition = box
                                                      .globalToLocal(
                                                        details.globalPosition,
                                                      );
                                                  _handleGaugeInteraction(
                                                    localPosition,
                                                    constraints.biggest,
                                                  );
                                                },
                                                onPanEnd: (details) {
                                                  // Keep dragging state true until user presses SET
                                                  // or set to false if you want it to reset
                                                },
                                                onTapDown: (details) {
                                                  final box =
                                                      context.findRenderObject()
                                                          as RenderBox;
                                                  final localPosition = box
                                                      .globalToLocal(
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
                                                      minimum: _minHumidity,
                                                      maximum: _maxHumidity,
                                                      startAngle: 150,
                                                      endAngle: 30,
                                                      showTicks: false,
                                                      showLabels: false,
                                                      axisLineStyle:
                                                          const AxisLineStyle(
                                                            thickness: 0.15,
                                                            thicknessUnit:
                                                                GaugeSizeUnit
                                                                    .factor,
                                                            color:
                                                                Colors.white24,
                                                            cornerStyle:
                                                                CornerStyle
                                                                    .bothCurve,
                                                          ),
                                                      pointers: [
                                                        RangePointer(
                                                          value:
                                                              _pendingHumidity,
                                                          width: 0.15,
                                                          color: Colors.white,
                                                          cornerStyle:
                                                              CornerStyle
                                                                  .bothCurve,
                                                          sizeUnit:
                                                              GaugeSizeUnit
                                                                  .factor,
                                                        ),
                                                        MarkerPointer(
                                                          value:
                                                              _pendingHumidity,
                                                          markerType:
                                                              MarkerType.circle,
                                                          color: Colors.white,
                                                          markerHeight: 20,
                                                          markerWidth: 20,
                                                          borderColor:
                                                              const Color(
                                                                0xFF3D8A8F,
                                                              ),
                                                          borderWidth: 3,
                                                        ),
                                                      ],
                                                      annotations: [
                                                        GaugeAnnotation(
                                                          angle: 90,
                                                          positionFactor: 0,
                                                          widget: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                "${_pendingHumidity.toStringAsFixed(1)}",
                                                                style: TextStyle(
                                                                  fontSize:
                                                                      isSmallScreen
                                                                      ? 24
                                                                      : 32,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                              const Text(
                                                                "%",
                                                                style: TextStyle(
                                                                  fontSize: 16,
                                                                  color: Colors
                                                                      .white70,
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
                                      ),

                                      const SizedBox(height: 20),

                                      // Action Button
                                      SizedBox(
                                        width: double.infinity,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          child: ElevatedButton(
                                            onPressed:
                                                esp32Provider.isConnected &&
                                                    !_isSettingValue
                                                ? _setHumidity
                                                : null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _getButtonColor(
                                                esp32Provider,
                                              ),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 40,
                                                    vertical: 16,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                              elevation: 4,
                                            ),
                                            child: _buildButtonContent(
                                              esp32Provider,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Add some bottom padding for safety
                                      SizedBox(height: isSmallScreen ? 10 : 20),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16.0,
                                              left: 10,
                                            ),
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
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
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
