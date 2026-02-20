import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiespl_surgeon_panel/humidity/humidityscreen.dart';
import 'package:wiespl_surgeon_panel/light/lightscreen.dart';
import 'package:wiespl_surgeon_panel/mgps/mgpsscreen.dart';
import 'package:wiespl_surgeon_panel/music/music.dart';
import 'package:wiespl_surgeon_panel/provider/stopwatch_provider.dart';
import 'package:wiespl_surgeon_panel/screens/clockwidget/clock.dart';
import 'package:wiespl_surgeon_panel/screens/entrance.dart';
import 'package:wiespl_surgeon_panel/services/esptwo.dart';
import 'package:wiespl_surgeon_panel/stopwatch/stopwatchscreen.dart';
import 'package:wiespl_surgeon_panel/temp/temperaturescreen.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  String? _currentMode;

  // All available item keys
  final List<String> _allItemKeys = [
    'temp',
    'rh',
    'lighting',
    'Stop Watch',
    'music',
    'mgps',
  ];

  // Get items based on current mode
  List<String> get _filteredItemKeys {
    switch (_currentMode) {
      case 'Passage':
        // Hide lighting (index 2) and mgps (index 5)
        return _allItemKeys
            .where((item) => item != 'lighting' && item != 'mgps')
            .toList();
      case 'Bronchi':
        // Hide only mgps (index 5)
        return _allItemKeys.where((item) => item != 'mgps').toList();
      default:
        // Main and Entrance show all items
        return _allItemKeys;
    }
  }

  // Send system status command to ESP32 using ESP32Provider
  void _sendSystemStatusCommand(bool isOn) {
    final esp32Provider = Provider.of<ESP32Provider>(context, listen: false);

    // Light 10 is system power in ESP32
    esp32Provider.toggleLight(10, isOn);

    _showSuccessSnackbar("System turned ${isOn ? 'ON' : 'OFF'}");
  }

  static const platform = MethodChannel('app_launcher_channel');

  // Timer for periodic updates
  Timer? _updateTimer;

  // Animation controllers
  late AnimationController _cardController;
  late Animation<Offset> _cardSlideAnimation;
  late AnimationController _bgController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final Random _random = Random();
  final List<MedicalParticle> _particles = [];

  // Responsive layout breakpoints
  static const double _mobileBreakpoint = 600;
  static const double _tabletBreakpoint = 1200;

  @override
  void initState() {
    super.initState();
    _loadCurrentMode();

    // Initialize ESP32 polling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final esp32Provider = Provider.of<ESP32Provider>(context, listen: false);
      esp32Provider.startPolling();
    });

    // Initialize particles
    for (int i = 0; i < 18; i++) {
      _particles.add(MedicalParticle(_random));
    }

    // Animation setup
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

    // Start periodic updates for HEPA status only
    _startPeriodicUpdates();
  }

  Future<void> _loadCurrentMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentMode = prefs.getString("mode") ?? 'Main';
    });
  }

  void _startPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final esp32Provider = Provider.of<ESP32Provider>(context, listen: false);
      // Refresh data periodically
      esp32Provider.refreshData();
    });
  }

  void _toggleMute() {
    // You might want to add mute functionality to ESP32Provider
    // For now, we'll just show a message
    _showSuccessSnackbar("Mute functionality coming soon");
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<String> fetchIpAddress() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      if (response.statusCode == 200) {
        return response.body;
      } else {
        return 'Failed to fetch IP'.tr;
      }
    } catch (e) {
      return 'Error: $e'.tr;
    }
  }

  static const Color _neonColor = Color(0xFF65D6F2);

  Future<void> handleTap(int itemNumber) async {
    // Get the actual item index from filtered list
    final filteredKeys = _filteredItemKeys;
    final originalIndex = _allItemKeys.indexOf(filteredKeys[itemNumber - 1]);

    switch (originalIndex + 1) {
      case 1:
        Get.to(() => TempGaugeScreen(), transition: Transition.rightToLeft);
        break;
      case 2:
        Get.to(() => HumidityGaugeScreen(), transition: Transition.rightToLeft);
        break;
      case 3:
        Get.to(() => LightIntensityPage(), transition: Transition.rightToLeft);
        break;
      case 4:
        Get.to(
          () => StylishStopwatchPage(),
          transition: Transition.rightToLeft,
        );
        break;
      case 5:
        Get.to(() => MusicPlayerScreen(), transition: Transition.rightToLeft);
        break;
      case 6:
        Get.to(() => GasStatusPage(), transition: Transition.rightToLeft);
        break;
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _cardController.dispose();
    _bgController.dispose();
    _pulseController.dispose();

    // Stop ESP32 polling
    final esp32Provider = Provider.of<ESP32Provider>(context, listen: false);
    esp32Provider.stopPolling();

    super.dispose();
  }

  // Helper method to determine screen size category
  ScreenSize _getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < _mobileBreakpoint) {
      return ScreenSize.mobile;
    } else if (width < _tabletBreakpoint) {
      return ScreenSize.tablet;
    } else {
      return ScreenSize.desktop;
    }
  }

  Widget buildScoreContainer(
    BuildContext context,
    String label,
    IconData icon,
    bool showTimer, {
    String? currentValue,
    required int itemNumber,
    double? customWidth,
  }) {
    final stopwatchProvider = Provider.of<StopwatchProvider>(
      context,
      listen: false,
    );
    final esp32Provider = Provider.of<ESP32Provider>(context);
    final screenSize = _getScreenSize(context);

    // Check if any sensor 1-6 has fault for MGPS
    bool isMgpsWithFault =
        itemNumber == 6 &&
        esp32Provider.sensorFaults
            .take(6) // Only check sensors 1-6 (indices 0-5)
            .any((fault) => fault == "1");

    // Responsive sizing
    double iconSize = screenSize == ScreenSize.mobile
        ? 28
        : screenSize == ScreenSize.tablet
        ? 32
        : 35;

    double fontSize = screenSize == ScreenSize.mobile
        ? 18
        : screenSize == ScreenSize.tablet
        ? 22
        : 26;

    double valueFontSize = screenSize == ScreenSize.mobile
        ? 20
        : screenSize == ScreenSize.tablet
        ? 22
        : 24;

    return Container(
      margin: const EdgeInsets.all(8),
      height: screenSize == ScreenSize.mobile
          ? MediaQuery.of(context).size.height * 0.18
          : screenSize == ScreenSize.tablet
          ? MediaQuery.of(context).size.height * 0.20
          : MediaQuery.of(context).size.height * 0.22,
      width:
          customWidth ??
          MediaQuery.of(context).size.width *
              (screenSize == ScreenSize.mobile
                  ? 0.28
                  : screenSize == ScreenSize.tablet
                  ? 0.25
                  : 0.22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMgpsWithFault ? Colors.red : Colors.white.withOpacity(1.0),
          width: 3.0,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: iconSize),
          const SizedBox(height: 6),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (currentValue != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                currentValue,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (showTimer && stopwatchProvider.isRunning)
            StreamBuilder<int>(
              stream: stopwatchProvider.stopWatchTimer.rawTime,
              initialData: stopwatchProvider.stopWatchTimer.rawTime.value,
              builder: (context, snapshot) {
                final displayTime = StopWatchTimer.getDisplayTime(
                  snapshot.data!,
                  milliSecond: false,
                );
                return Text(
                  displayTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final esp32Provider = Provider.of<ESP32Provider>(context);
    final filteredKeys = _filteredItemKeys;
    final screenSize = _getScreenSize(context);

    // For mobile, use single column layout
    if (screenSize == ScreenSize.mobile) {
      return _buildMobileLayout(filteredKeys, esp32Provider);
    }

    // For tablet and desktop, calculate item width based on number of items
    double itemWidth;
    switch (filteredKeys.length) {
      case 4:
        itemWidth =
            MediaQuery.of(context).size.width *
            (screenSize == ScreenSize.tablet ? 0.20 : 0.18);
        break;
      case 5:
        itemWidth =
            MediaQuery.of(context).size.width *
            (screenSize == ScreenSize.tablet ? 0.18 : 0.16);
        break;
      default:
        itemWidth =
            MediaQuery.of(context).size.width *
            (screenSize == ScreenSize.tablet ? 0.25 : 0.22);
    }

    // Create rows based on filtered items
    List<Widget> rows = [];

    if (filteredKeys.length <= 3) {
      // Single row if 3 or fewer items
      rows.add(
        _buildRow(
          filteredKeys,
          0,
          filteredKeys.length,
          esp32Provider,
          itemWidth,
        ),
      );
    } else {
      // Two rows for 4-6 items
      rows.add(_buildRow(filteredKeys, 0, 3, esp32Provider, itemWidth));
      rows.add(SizedBox(height: screenSize == ScreenSize.tablet ? 10 : 20));
      rows.add(
        _buildRow(
          filteredKeys,
          3,
          filteredKeys.length,
          esp32Provider,
          itemWidth,
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: screenSize == ScreenSize.tablet ? 40 : 80),
          ...rows,
          SizedBox(height: screenSize == ScreenSize.tablet ? 20 : 40),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    List<String> filteredKeys,
    ESP32Provider esp32Provider,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Center the items on mobile
          Center(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: List.generate(filteredKeys.length, (index) {
                final itemKey = filteredKeys[index];
                final itemNumber = index + 1;
                final originalIndex = _allItemKeys.indexOf(itemKey) + 1;

                return _buildMobileItem(
                  itemKey,
                  itemNumber,
                  originalIndex,
                  esp32Provider,
                );
              }),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMobileItem(
    String itemKey,
    int itemNumber,
    int originalIndex,
    ESP32Provider esp32Provider,
  ) {
    Widget item;
    switch (itemKey) {
      case 'temp':
        item = GestureDetector(
          onTap: () => handleTap(itemNumber),
          child: buildScoreContainer(
            context,
            itemKey.tr,
            Icons.thermostat,
            false,
            currentValue: '${esp32Provider.currentTemperature}°C',
            itemNumber: originalIndex,
            customWidth: MediaQuery.of(context).size.width * 0.4,
          ),
        );
        break;
      case 'rh':
        item = GestureDetector(
          onTap: () => handleTap(itemNumber),
          child: buildScoreContainer(
            context,
            itemKey.tr,
            Icons.water_drop_outlined,
            false,
            currentValue: '${esp32Provider.currentHumidity}%',
            itemNumber: originalIndex,
            customWidth: MediaQuery.of(context).size.width * 0.4,
          ),
        );
        break;
      case 'lighting':
        item = GestureDetector(
          onTap: () => handleTap(itemNumber),
          child: buildScoreContainer(
            context,
            itemKey.tr,
            Icons.lightbulb_outline,
            false,
            itemNumber: originalIndex,
            customWidth: MediaQuery.of(context).size.width * 0.4,
          ),
        );
        break;
      case 'Stop Watch':
        item = GestureDetector(
          onTap: () => handleTap(itemNumber),
          child: buildScoreContainer(
            context,
            itemKey.tr,
            Icons.timer,
            true,
            itemNumber: originalIndex,
            customWidth: MediaQuery.of(context).size.width * 0.4,
          ),
        );
        break;
      case 'music':
        item = GestureDetector(
          onTap: () => handleTap(itemNumber),
          child: buildScoreContainer(
            context,
            itemKey.tr,
            Icons.music_note,
            false,
            itemNumber: originalIndex,
            customWidth: MediaQuery.of(context).size.width * 0.4,
          ),
        );
        break;
      case 'mgps':
        item = GestureDetector(
          onTap: () => handleTap(itemNumber),
          child: buildScoreContainer(
            context,
            itemKey.tr,
            Icons.map,
            false,
            itemNumber: originalIndex,
            customWidth: MediaQuery.of(context).size.width * 0.4,
          ),
        );
        break;
      default:
        item = Container();
    }
    return item;
  }

  Widget _buildRow(
    List<String> filteredKeys,
    int start,
    int end,
    ESP32Provider esp32Provider,
    double itemWidth,
  ) {
    final screenSize = _getScreenSize(context);

    List<Widget> rowItems = [];

    for (int i = start; i < end && i < filteredKeys.length; i++) {
      final itemKey = filteredKeys[i];
      final itemNumber = i + 1;
      final originalIndex = _allItemKeys.indexOf(itemKey) + 1;

      Widget item;
      switch (itemKey) {
        case 'temp':
          item = GestureDetector(
            onTap: () => handleTap(itemNumber),
            child: buildScoreContainer(
              context,
              itemKey.tr,
              Icons.thermostat,
              false,
              currentValue: '${esp32Provider.currentTemperature}°C',
              itemNumber: originalIndex,
              customWidth: itemWidth,
            ),
          );
          break;
        case 'rh':
          item = GestureDetector(
            onTap: () => handleTap(itemNumber),
            child: buildScoreContainer(
              context,
              itemKey.tr,
              Icons.water_drop_outlined,
              false,
              currentValue: '${esp32Provider.currentHumidity}%',
              itemNumber: originalIndex,
              customWidth: itemWidth,
            ),
          );
          break;
        case 'lighting':
          item = GestureDetector(
            onTap: () => handleTap(itemNumber),
            child: buildScoreContainer(
              context,
              itemKey.tr,
              Icons.lightbulb_outline,
              false,
              itemNumber: originalIndex,
              customWidth: itemWidth,
            ),
          );
          break;
        case 'Stop Watch':
          item = GestureDetector(
            onTap: () => handleTap(itemNumber),
            child: buildScoreContainer(
              context,
              itemKey.tr,
              Icons.timer,
              true,
              itemNumber: originalIndex,
              customWidth: itemWidth,
            ),
          );
          break;
        case 'music':
          item = GestureDetector(
            onTap: () => handleTap(itemNumber),
            child: buildScoreContainer(
              context,
              itemKey.tr,
              Icons.music_note,
              false,
              itemNumber: originalIndex,
              customWidth: itemWidth,
            ),
          );
          break;
        case 'mgps':
          item = GestureDetector(
            onTap: () => handleTap(itemNumber),
            child: buildScoreContainer(
              context,
              itemKey.tr,
              Icons.map,
              false,
              itemNumber: originalIndex,
              customWidth: itemWidth,
            ),
          );
          break;
        default:
          item = Container();
      }

      rowItems.add(item);
      if (i < end - 1 && i < filteredKeys.length - 1) {
        rowItems.add(
          SizedBox(width: screenSize == ScreenSize.tablet ? 10 : 20),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        left: screenSize == ScreenSize.mobile
            ? 0
            : screenSize == ScreenSize.tablet
            ? 50
            : 190,
      ),
      child: Row(
        mainAxisAlignment: screenSize == ScreenSize.mobile
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rowItems,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final screenSize = _getScreenSize(context);
    final esp32Provider = Provider.of<ESP32Provider>(context);

    if (screenSize == ScreenSize.mobile) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          children: [
            // Welcome text on top for mobile
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "WELCOME TO WIESPL CONTROL PANEL",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Clock on left
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Transform.scale(
                      scale: 0.8,
                      child: ClockDisplay(neonColor: _neonColor),
                    ),
                  ),
                ),
                // Language and ESP32 status on right
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      DropdownButton<String>(
                        value: Get.locale?.languageCode ?? 'en',
                        icon: const Icon(
                          Icons.language,
                          color: Colors.white,
                          size: 24,
                        ),
                        dropdownColor: Colors.blue[800],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        underline: Container(),
                        items: const [
                          DropdownMenuItem(
                            value: 'en',
                            child: Text(
                              'English',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'hi',
                            child: Text(
                              'हिंदी',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'ar',
                            child: Text(
                              'العربية',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value != null) {
                            Get.updateLocale(Locale(value));
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: esp32Provider.isConnected
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: esp32Provider.isConnected
                                ? Colors.green
                                : Colors.red,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          esp32Provider.isConnected ? "" : "",
                          style: TextStyle(
                            color: esp32Provider.isConnected
                                ? Colors.green
                                : Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
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
    } else {
      // Tablet and Desktop layout
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ClockDisplay(neonColor: _neonColor),
            const SizedBox(),
            Text(
              "WELCOME TO WIESPL CONTROL PANEL",
              style: TextStyle(
                color: Colors.white,
                fontSize: screenSize == ScreenSize.tablet ? 20 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(),
            Row(
              children: [
                DropdownButton<String>(
                  value: Get.locale?.languageCode ?? 'en',
                  icon: const Icon(Icons.language, color: Colors.white),
                  dropdownColor: Colors.blue[800],
                  style: const TextStyle(color: Colors.white),
                  underline: Container(),
                  items: const [
                    DropdownMenuItem(
                      value: 'en',
                      child: Text(
                        'English',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'hi',
                      child: Text(
                        'हिंदी',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'ar',
                      child: Text(
                        'العربية',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      Get.updateLocale(Locale(value));
                    }
                  },
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    // horizontal: 12,
                    // vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: esp32Provider.isConnected
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: esp32Provider.isConnected
                          ? Colors.green
                          : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    esp32Provider.isConnected ? "" : "",
                    style: TextStyle(
                      color: esp32Provider.isConnected
                          ? Colors.green
                          : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFooter(BuildContext context) {
    final screenSize = _getScreenSize(context);
    final esp32Provider = Provider.of<ESP32Provider>(context);

    if (screenSize == ScreenSize.mobile) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Logo section
            Container(
              height: 80,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Image.asset(
                  'assets/app_logo-removebg-preview.png',
                  height: 70,
                  width: 160,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 15),

            // System status section
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Container(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 12,
                //     vertical: 6,
                //   ),
                //   decoration: BoxDecoration(
                //     // Using pressure positive as HEPA status for now
                //     color: esp32Provider.isPressurePositive
                //         ? Colors.green.withOpacity(0.2)
                //         : Colors.red.withOpacity(0.2),
                //     borderRadius: BorderRadius.circular(15),
                //     border: Border.all(
                //       color: esp32Provider.isPressurePositive
                //           ? Colors.green
                //           : Colors.red,
                //       width: 2,
                //     ),
                //   ),
                //   child: Row(
                //     mainAxisSize: MainAxisSize.min,
                //     children: [
                //       Icon(
                //         esp32Provider.isPressurePositive
                //             ? Icons.air
                //             : Icons.warning,
                //         color: esp32Provider.isPressurePositive
                //             ? Colors.green
                //             : Colors.red,
                //         size: 16,
                //       ),
                //       const SizedBox(width: 6),
                //       Text(
                //         esp32Provider.isPressurePositive
                //             ? "HEPA Healthy"
                //             : "HEPA Fault",
                //         style: TextStyle(
                //           color: esp32Provider.isPressurePositive
                //               ? Colors.green
                //               : Colors.red,
                //           fontSize: 14,
                //           fontWeight: FontWeight.bold,
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
                const SizedBox(width: 20),

                // System switch (Light 10)
                Column(
                  children: [
                    Text(
                      "system_status".tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      alignment: Alignment.center,
                      height: 40, // Give it enough height
                      child: Transform.scale(
                        scale: 1.5,
                        child: Switch(
                          value: esp32Provider.light10,
                          activeColor: Colors.lightBlueAccent,
                          inactiveThumbColor: Colors.grey.shade300,
                          inactiveTrackColor: Colors.grey.shade500,
                          onChanged: (value) async {
                            if (!value) {
                              bool confirm = await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Confirm"),
                                  content: const Text(
                                    "Are you sure you want to turn off the system?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text("Yes"),
                                    ),
                                  ],
                                ),
                              );
                              if (!confirm) return;
                            }

                            try {
                              await esp32Provider.toggleLight(10, value);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Failed to ${value ? 'start' : 'stop'} system",
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),

                // Volume control
                IconButton(
                  icon: const Icon(
                    Icons.volume_up,
                    size: 32,
                    color: Colors.white,
                  ),
                  onPressed: _toggleMute,
                  tooltip: "Volume Control",
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // Tablet and Desktop footer
      return Padding(
        padding: EdgeInsets.all(screenSize == ScreenSize.tablet ? 12.0 : 18.0),
        child: Row(
          children: [
            // Logo
            Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20.0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        height: screenSize == ScreenSize.tablet ? 100 : 120,
                        width: screenSize == ScreenSize.tablet ? 200 : 270,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.0,
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/image.png',
                            height: screenSize == ScreenSize.tablet ? 80 : 100,
                            width: screenSize == ScreenSize.tablet ? 240 : 300,
                            fit: BoxFit.contain,
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
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        height: screenSize == ScreenSize.tablet ? 80 : 100,
                        width: screenSize == ScreenSize.tablet ? 180 : 250,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.0,
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/app_logo-removebg-preview.png',
                            height: screenSize == ScreenSize.tablet ? 80 : 100,
                            width: screenSize == ScreenSize.tablet ? 240 : 300,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),

            // System status (using pressure as indicator)
            Column(
              children: [
                Text(
                  "system_status".tr,
                  style: const TextStyle(
                    color: Colors.transparent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (esp32Provider.sensorFaults.length > 9 &&
                            esp32Provider.sensorFaults[9] == "0")
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          (esp32Provider.sensorFaults.length > 9 &&
                              esp32Provider.sensorFaults[9] == "0")
                          ? Colors.green
                          : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (esp32Provider.sensorFaults.length > 9 &&
                                esp32Provider.sensorFaults[9] == "0")
                            ? Icons.air
                            : Icons.warning,
                        color:
                            (esp32Provider.sensorFaults.length > 9 &&
                                esp32Provider.sensorFaults[9] == "0")
                            ? Colors.green
                            : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (esp32Provider.sensorFaults.length > 9 &&
                                esp32Provider.sensorFaults[9] == "0")
                            ? "HEPA Healthy"
                            : "HEPA Fault",
                        style: TextStyle(
                          color:
                              (esp32Provider.sensorFaults.length > 9 &&
                                  esp32Provider.sensorFaults[9] == "0")
                              ? Colors.green
                              : Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // System switch (Light 10)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "system_status".tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Consumer<ESP32Provider>(
                  builder: (context, esp32Provider, child) {
                    bool isSwitching = false;

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Switch(
                          value:
                              esp32Provider.light10, // Light 10 is system power
                          activeColor: Colors.lightBlueAccent,
                          inactiveThumbColor: Colors.grey.shade300,
                          inactiveTrackColor: Colors.grey.shade500,
                          onChanged: isSwitching
                              ? null
                              : (value) async {
                                  if (!value) {
                                    bool confirm = await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text("Confirm"),
                                        content: const Text(
                                          "Are you sure you want to turn off the system?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                            child: const Text("Cancel"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text("Yes"),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (!confirm) return;
                                  }

                                  try {
                                    await esp32Provider.toggleLight(10, value);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Failed to ${value ? 'start' : 'stop'} system",
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                        ),
                        if (isSwitching)
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),

            // Volume control
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "system_status".tr,
                  style: const TextStyle(
                    color: Colors.transparent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.volume_up,
                    size: 42,
                    color: Colors.white,
                  ),
                  onPressed: _toggleMute,
                  tooltip: "Volume Control",
                ),
              ],
            ),
            const SizedBox(width: 12),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final esp32Provider = Provider.of<ESP32Provider>(context);

    return Scaffold(
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
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height,
            child: Column(
              children: [
                // Header
                _buildHeader(context),

                // Main Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 70, top: 40),
                    child: _buildMainContent(),
                  ),
                ),

                // Footer
                _buildFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum ScreenSize { mobile, tablet, desktop }

// Particle classes
class MedicalParticle {
  final Random random;
  double x = 0;
  double y = 0;
  double dx = 0;
  double dy = 0;
  double size = 0;

  MedicalParticle(this.random) {
    reset();
  }

  void reset() {
    x = random.nextDouble();
    y = random.nextDouble();
    dx = (random.nextDouble() - 0.5) * 0.002;
    dy = (random.nextDouble() - 0.5) * 0.002;
    size = random.nextDouble() * 3 + 1;
  }
}

class ClinicalBackgroundPainter extends CustomPainter {
  final double t;
  final List<MedicalParticle> particles;

  ClinicalBackgroundPainter({required this.t, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromARGB(255, 35, 87, 136)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Offset.zero & size, paint);

    // Draw particles
    final particlePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (var particle in particles) {
      particle.x += particle.dx;
      particle.y += particle.dy;

      if (particle.x < 0 || particle.x > 1) particle.dx *= -1;
      if (particle.y < 0 || particle.y > 1) particle.dy *= -1;

      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        particlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(ClinicalBackgroundPainter oldDelegate) => true;
}
