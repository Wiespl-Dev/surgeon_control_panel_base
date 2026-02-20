import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wiespl_surgeon_panel/services/esptwo.dart'; // Updated import

class ORStatusMonitor extends StatefulWidget {
  @override
  State<ORStatusMonitor> createState() => _ORStatusMonitorState();
}

class _ORStatusMonitorState extends State<ORStatusMonitor>
    with TickerProviderStateMixin {
  // UI animations
  late AnimationController _cardController;
  late Animation<Offset> _cardSlideAnimation;
  late AnimationController _bgController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Date and time
  late Timer _dateTimeTimer;
  DateTime _currentDateTime = DateTime.now();

  // Pressure adjustment
  final TextEditingController _pressureAdjustController =
      TextEditingController();
  final Random _random = Random();
  final List<MedicalParticle> _particles = [];

  @override
  void initState() {
    super.initState();

    // Initialize ESP32 provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final espProvider = Provider.of<ESP32Provider>(context, listen: false);
      espProvider.startPolling();
    });

    // particles
    for (int i = 0; i < 18; i++) {
      _particles.add(MedicalParticle(_random));
    }

    // animations
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

    _cardController.forward();

    // Initialize date/time timer
    _dateTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentDateTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _cardController.dispose();
    _bgController.dispose();
    _pulseController.dispose();
    _dateTimeTimer.cancel();
    _pressureAdjustController.dispose();

    // Stop ESP32 polling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final espProvider = Provider.of<ESP32Provider>(context, listen: false);
      espProvider.stopPolling();
    });

    super.dispose();
  }

  // Date and time formatting methods
  String _formattedDate() {
    return "${_currentDateTime.day.toString().padLeft(2, '0')} ${_monthName(_currentDateTime.month)} ${_currentDateTime.year}";
  }

  String _formattedTime() {
    final hour = _currentDateTime.hour > 12
        ? _currentDateTime.hour - 12
        : (_currentDateTime.hour == 0 ? 12 : _currentDateTime.hour);
    final ampm = _currentDateTime.hour >= 12 ? "PM" : "AM";
    return "${hour.toString()}:${_currentDateTime.minute.toString().padLeft(2, '0')} $ampm";
  }

  String _monthName(int m) {
    const months = [
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
    ];
    return months[m - 1];
  }

  // Pressure adjustment methods
  void _showPressureAdjustmentDialog(
    ESP32Provider espProvider,
    String currentPressure,
  ) {
    _pressureAdjustController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C6975),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        title: Text(
          'Adjust Entrance Pressure',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current Pressure: $currentPressure Pa',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pressureAdjustController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Enter value',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
                fillColor: Colors.white.withOpacity(0.1),
                filled: true,
              ),
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _adjustPressure(false, espProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '–',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _adjustPressure(true, espProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '+',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _adjustPressure(bool isPositive, ESP32Provider espProvider) {
    final input = _pressureAdjustController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Please enter a value'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final adjustment = double.tryParse(input);
    if (adjustment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Please enter a valid number'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Get current pressure value
    final currentPressure =
        double.tryParse(espProvider.getFormattedPressure()) ?? 0;

    // Calculate new pressure
    double newPressure;
    if (isPositive) {
      newPressure = currentPressure + adjustment;
    } else {
      newPressure = currentPressure - adjustment;
    }

    // Ensure pressure is never negative (minimum 0)
    if (newPressure < 0) {
      newPressure = 0;
    }

    // TODO: Implement pressure adjustment in ESP32Provider
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isPositive ? Colors.green : Colors.red,
        content: Text(
          'Pressure ${isPositive ? 'increased' : 'decreased'} by $adjustment Pa\nNew pressure: ${newPressure.toStringAsFixed(0)} Pa',
          style: TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.of(context).pop();
  }

  Widget _buildConnectionStatus(ESP32Provider espProvider) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (espProvider.isConnected) {
      statusColor = Colors.transparent;
      statusText = "";
      statusIcon = Icons.wifi;
    } else {
      statusColor = Colors.redAccent;
      statusText = "Disconnected";
      statusIcon = Icons.signal_wifi_off;
    }

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Icon(statusIcon, color: statusColor, size: 16),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Get sensor data from ESP32 provider
  _SensorData _getSensorData(ESP32Provider espProvider) {
    // Get formatted pressure from ESP32 provider (should already have no leading zeros)
    String pressureValue = espProvider.getFormattedPressure();

    // Ensure pressure is displayed as integer without decimals
    if (pressureValue.contains('.')) {
      pressureValue = pressureValue.split('.')[0];
    }

    // Additional safety: if the value has leading zeros, remove them
    // This is a double-check in case the provider doesn't handle it properly
    if (pressureValue.isNotEmpty && pressureValue != "0") {
      // Remove leading zeros but keep the sign if present
      if (pressureValue.startsWith('-')) {
        // Handle negative values
        String absoluteValue = pressureValue.substring(1);
        if (absoluteValue.isNotEmpty) {
          int intValue = int.tryParse(absoluteValue) ?? 0;
          pressureValue = '-${intValue.toString()}';
        }
      } else {
        // Handle positive values
        int intValue = int.tryParse(pressureValue) ?? 0;
        pressureValue = intValue.toString();
      }
    }

    return _SensorData(
      temperature: espProvider.currentTemperature,
      humidity: espProvider.currentHumidity,
      pressure: pressureValue,
      isPressurePositive: espProvider.isPressurePositive,
      pressureColor: espProvider.getPressureColor(),
    );
  }

  // Helper method to handle toggle actions
  void _handleToggle(String type, bool value, ESP32Provider espProvider) {
    switch (type) {
      case 'defumigation':
        espProvider.toggleDefumigation(value);
        break;
      case 'system':
        espProvider.toggleSystemPower(value);
        break;
      case 'night':
        espProvider.toggleDayNightMode(value);
        break;
    }
  }

  // Helper method to get toggle states
  bool _getToggleState(String type, ESP32Provider espProvider) {
    switch (type) {
      case 'defumigation':
        return espProvider.defumigation;
      case 'system':
        return espProvider.systemPower;
      case 'night':
        return espProvider.dayNightMode;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ESP32Provider>(
      builder: (context, espProvider, child) {
        final sensorData = _getSensorData(espProvider);

        return Scaffold(
          backgroundColor: const Color(0xFF3D8A8F),
          body: Stack(
            children: [
              AnimatedBuilder(
                animation: _bgController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ClinicalBackgroundPainter(
                      t: _bgController.value,
                      particles: _particles,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () {
                              _showPressureAdjustmentDialog(
                                espProvider,
                                sensorData.pressure,
                              );
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20.0),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 10.0,
                                        sigmaY: 10.0,
                                      ),
                                      child: Container(
                                        height: 100,
                                        width: 200,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.3),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Center(
                                          child: Image.asset(
                                            'assets/image.png',
                                            height: 70,
                                            width: 300,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20.0),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 10.0,
                                        sigmaY: 10.0,
                                      ),
                                      child: Container(
                                        height: 100,
                                        width: 180,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.3),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Center(
                                          child: Image.asset(
                                            'assets/app_logo-removebg-preview.png',
                                            height: 80,
                                            width: 300,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              // Connection status
                              _buildConnectionStatus(espProvider),
                              const SizedBox(width: 8),
                              // Add Pressure Adjustment Button
                              // IconButton(
                              //   onPressed: () => _showPressureAdjustmentDialog(
                              //     espProvider,
                              //     sensorData.pressure,
                              //   ),
                              //   icon: const Icon(
                              //     Icons.add_chart_outlined,
                              //     color: Colors.white70,
                              //     size: 24,
                              //   ),
                              //   tooltip: "Adjust Pressure",
                              // ),
                              const SizedBox(width: 8),
                              // Refresh button
                              IconButton(
                                onPressed: () {
                                  if (espProvider.isConnected) {
                                    espProvider.refreshData();
                                  } else {
                                    espProvider.startPolling();
                                  }
                                },
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.white70,
                                  size: 24,
                                ),
                                tooltip: "Refresh Sensor Data",
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        "OR Status Monitor",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: SlideTransition(
                          position: _cardSlideAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Line 1: Temperature, R/H, and Room Pressure
                                _buildThreeItemRow(
                                  item1: _statusTile(
                                    title: "Temperature",
                                    value: sensorData.temperature,
                                    unit: "°C",
                                    icon: Icons.thermostat_outlined,
                                  ),
                                  item2: _statusTile(
                                    title: "R/H",
                                    value: sensorData.humidity,
                                    unit: "%",
                                    icon: Icons.water_drop_outlined,
                                  ),
                                  item3: _pressureStatusTile(
                                    title: "Room Pressure",
                                    value: sensorData.pressure,
                                    color: sensorData.pressureColor,
                                    icon: Icons.compress_outlined,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                CustomPaint(
                                  size: Size(
                                    MediaQuery.of(context).size.width,
                                    34,
                                  ),
                                  painter: SimpleSeparatorPainter(),
                                ),
                                // Line 2: Time and Date
                                _buildStatusRow(
                                  title1: "Time",
                                  value1: _formattedTime(),
                                  icon1: Icons.access_time_outlined,
                                  title2: "Date",
                                  value2: _formattedDate(),
                                  icon2: Icons.calendar_today_outlined,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Toggle buttons row - Reordered to match logical sequence
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Defumigation - Light 8
                          _customToggle(
                            label: "Defumigation",
                            value: _getToggleState('defumigation', espProvider),
                            icon: Icons.wb_cloudy_outlined,
                            onChanged: (value) {
                              _handleToggle('defumigation', value, espProvider);
                            },
                          ),
                          // Night - Light 9 (should come before System/Light 10)
                          _customToggle(
                            label: "Night",
                            value: _getToggleState('night', espProvider),
                            icon: Icons.mode_night_outlined,
                            onChanged: (value) {
                              _handleToggle('night', value, espProvider);
                            },
                          ),
                          // System - Light 10
                          _customToggle(
                            label: "System",
                            value: _getToggleState('system', espProvider),
                            icon: Icons.power_settings_new,
                            onChanged: (value) {
                              _handleToggle('system', value, espProvider);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pressureStatusTile({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Icon(icon, color: Colors.white70, size: 22),
                );
              },
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              "Pa",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThreeItemRow({
    required Widget item1,
    required Widget item2,
    required Widget item3,
  }) {
    return Row(
      children: [
        Expanded(child: item1),
        const SizedBox(width: 12),
        Expanded(child: item2),
        const SizedBox(width: 12),
        Expanded(child: item3),
      ],
    );
  }

  Widget _buildStatusRow({
    required String title1,
    required String value1,
    required IconData icon1,
    required String title2,
    required String value2,
    required IconData icon2,
  }) {
    return Row(
      children: [
        Expanded(
          child: _statusTile(title: title1, value: value1, icon: icon1),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statusTile(title: title2, value: value2, icon: icon2),
        ),
      ],
    );
  }

  Widget _statusTile({
    required String title,
    required String value,
    String? unit,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Icon(icon, color: Colors.white70, size: 22),
                );
              },
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (title == "Date" || title == "Time")
              Text(
                value,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
            else
              _AnimatedCounter(value: value),
            if (unit != null)
              Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _customToggle({
    required String label,
    required bool value,
    required IconData icon,
    required Function(bool) onChanged,
  }) {
    return Flexible(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              width: 56,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? const Color(0xFF2ECC71) : Colors.white24,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
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
  }
}

// Helper class to hold sensor data
class _SensorData {
  final String temperature;
  final String humidity;
  final String pressure;
  final bool isPressurePositive;
  final Color pressureColor;

  _SensorData({
    required this.temperature,
    required this.humidity,
    required this.pressure,
    required this.isPressurePositive,
    required this.pressureColor,
  });
}

class _AnimatedCounter extends StatefulWidget {
  final String value;
  const _AnimatedCounter({Key? key, required this.value}) : super(key: key);

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _currentValue = "0";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _updateValue();
  }

  @override
  void didUpdateWidget(covariant _AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _updateValue();
    }
  }

  void _updateValue() {
    // Handle both integer and decimal values
    final start = double.tryParse(_currentValue) ?? 0.0;
    final end = double.tryParse(widget.value) ?? 0.0;
    _animation = Tween<double>(
      begin: start,
      end: end,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Format the value to remove decimal places for integer values
        final animatedValue = _animation.value;
        if (animatedValue == animatedValue.truncateToDouble()) {
          _currentValue = animatedValue.toInt().toString();
        } else {
          _currentValue = animatedValue.toStringAsFixed(1);
        }
        return Text(
          _currentValue,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      },
    );
  }
}

class SimpleSeparatorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant SimpleSeparatorPainter oldDelegate) => false;
}

class MedicalParticle {
  double x, y, size, vx, vy, opacity;
  final Random _random;

  MedicalParticle(this._random)
    : x = _random.nextDouble(),
      y = _random.nextDouble(),
      size = _random.nextDouble() * 2 + 0.6,
      vx = _random.nextDouble() * 0.0008 - 0.0004,
      vy = _random.nextDouble() * 0.0008 - 0.0004,
      opacity = 0.06 + _random.nextDouble() * 0.06;

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
  final double t; // 0..1
  final List<MedicalParticle> particles;
  ClinicalBackgroundPainter({required this.t, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gT = (sin(t * 2 * pi) + 1) / 2 * 0.2;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(const Color(0xFF0F3D3E), const Color(0xFF2C6975), gT)!,
        Color.lerp(const Color(0xFF144552), const Color(0xFF205375), gT)!,
        Color.lerp(const Color(0xFF16324F), const Color(0xFF112031), gT)!,
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 0.5;
    const double step = 40;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final rayPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withOpacity(0.07), Colors.transparent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);

    final rayPath = Path()
      ..moveTo(size.width * (0.15 + t * 0.05), 0)
      ..lineTo(size.width * (0.35 + t * 0.05), 0)
      ..lineTo(size.width * (0.75 + t * 0.05), size.height)
      ..lineTo(size.width * (0.55 + t * 0.05), size.height)
      ..close();
    canvas.drawPath(rayPath, rayPaint);

    final glowPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);

    canvas.drawCircle(
      Offset(size.width * 0.25, size.height * (0.35 + 0.05 * sin(t * 2 * pi))),
      120,
      glowPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * (0.65 + 0.05 * cos(t * 2 * pi))),
      100,
      glowPaint,
    );

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var p in particles) {
      p.update(t);
      dotPaint.color = Colors.white.withOpacity(p.opacity);
      final cx = p.x * size.width;
      final cy = p.y * size.height;
      canvas.drawCircle(Offset(cx, cy), p.size, dotPaint);
    }

    _drawECG(canvas, size, t);
  }

  void _drawECG(Canvas canvas, Size size, double phase) {
    final paint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final amplitude = size.height * 0.03;
    final baselineY = size.height * 0.22;
    final speed = 0.6;
    final offsetX = phase * size.width * speed;

    bool first = true;
    for (double x = -size.width; x <= size.width * 2; x += 4) {
      final local = (x / 80.0);
      final beat = sin(local * 2 * pi);
      final spike = exp(-pow((local % 6.0) - 3.0, 2)) * 6.0;
      final yOffset = beat * amplitude * 0.6 + (spike * amplitude * 0.12);
      final px = x - offsetX % (size.width * 1.2);
      final py = baselineY + yOffset + 4 * sin((phase * 2 * pi) + x * 0.01);
      if (first) {
        path.moveTo(px, py);
        first = false;
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ClinicalBackgroundPainter oldDelegate) => true;
}
