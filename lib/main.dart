import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player/video_player.dart';

import 'package:wiespl_surgeon_panel/music/mupro.dart';
import 'package:wiespl_surgeon_panel/provider/clock/clockprovider.dart';
import 'package:wiespl_surgeon_panel/screens/entrance.dart';
import 'package:wiespl_surgeon_panel/screens/home.dart';
import 'package:wiespl_surgeon_panel/services/esp.dart';
import 'package:wiespl_surgeon_panel/services/esptwo.dart';
import 'package:wiespl_surgeon_panel/services/usb_services.dart';
import 'provider/stopwatch_provider.dart';

/// ==========================
/// Localization Service
/// ==========================
class LocalizationService extends Translations {
  LocalizationService._();
  static final LocalizationService instance = LocalizationService._();

  final Map<String, Map<String, String>> _translations = {};
  Locale _locale = const Locale('en');

  Future<void> init() async {
    try {
      for (final lang in ['en', 'hi', 'ar']) {
        final jsonStr = await rootBundle.loadString('assets/la/$lang.json');
        final Map<String, dynamic> data = json.decode(jsonStr);
        _translations[lang] = data.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (e) {
      debugPrint('Error loading translations: $e');
      _translations['en'] = {};
      _translations['hi'] = {};
      _translations['ar'] = {};
    }
  }

  void setLocale(Locale locale) {
    _locale = locale;
    Get.updateLocale(locale);
  }

  Locale get locale => _locale;

  @override
  Map<String, Map<String, String>> get keys => _translations;

  String t(String key, {Map<String, String>? params}) {
    var text = _translations[_locale.languageCode]?[key] ?? key;
    params?.forEach((p, v) => text = text.replaceAll('{$p}', v));
    return text;
  }
}

/// ==========================
/// MAIN
/// ==========================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);

  await LocalizationService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StopwatchProvider()),
        ChangeNotifierProvider(create: (_) => ClockProvider()),
        ChangeNotifierProvider(create: (context) => ESP32State()),
        ChangeNotifierProvider(create: (context) => ESP32Provider()),
        ChangeNotifierProvider(create: (context) => MusicPlayerProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString("uniqueCode");
    final mode = prefs.getString("mode");
    final espIp = prefs.getString("espIp");

    if (code != null && mode != null && espIp != null) {
      switch (mode) {
        case 'Main':
          return Home();
        case 'Entrance':
          return ORStatusMonitor();
        case 'Passage':
          return Home();
        case 'Bronchi':
          return Home();
        default:
          return Home();
      }
    }
    return const SplashScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getInitialScreen(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          locale: LocalizationService.instance.locale,
          fallbackLocale: const Locale('en'),
          translations: LocalizationService.instance,
          supportedLocales: const [Locale('en'), Locale('hi'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: snapshot.data!,
        );
      },
    );
  }
}

/// ==========================
/// Splash Screen
/// ==========================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/wiespl_indro.mp4')
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
    _controller.setLooping(false);

    _controller.addListener(() {
      if (_controller.value.position == _controller.value.duration) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _controller.value.isInitialized
          ? Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

/// ==========================
/// Login Page
/// ==========================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _espIpController = TextEditingController();
  final TextEditingController _doctorController = TextEditingController();
  final TextEditingController _patientController = TextEditingController();
  final TextEditingController _surgeryController = TextEditingController();

  String? _selectedMode;
  String? _selectedOT;

  final List<String> _modes = ['Main', 'Entrance', 'Passage', 'Bronchi'];
  final List<String> _otNumbers = [
    'OT - 1',
    'OT - 2',
    'OT - 3',
    'OT - 4',
    'OT - 5',
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString("uniqueCode");
    final savedEspIp = prefs.getString("espIp");
    final savedMode = prefs.getString("mode");
    final savedOT = prefs.getString("otNumber");
    final savedDoctor = prefs.getString("doctorName");
    final savedPatient = prefs.getString("patientName");
    final savedSurgery = prefs.getString("surgeryName");

    setState(() {
      if (savedCode != null) _codeController.text = savedCode;
      if (savedEspIp != null) _espIpController.text = savedEspIp;
      if (savedMode != null) _selectedMode = savedMode;
      if (savedOT != null) _selectedOT = savedOT;
      // if (savedDoctor != null) _doctorController.text = savedDoctor;
      // if (savedPatient != null) _patientController.text = savedPatient;
      // if (savedSurgery != null) _surgeryController.text = savedSurgery;
    });
  }

  Future<void> _onLogin() async {
    if (_codeController.text.isEmpty || _selectedMode == null) {
      Get.snackbar(
        "Error",
        "Please enter code and select mode",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return;
    }

    String espIp = _espIpController.text.trim();
    if (espIp.isNotEmpty && !_isValidIpAddress(espIp)) {
      Get.snackbar(
        "Error",
        "Please enter a valid IP address (e.g., 192.168.4.1)",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("uniqueCode", _codeController.text);
    await prefs.setString("mode", _selectedMode!);
    if (espIp.isNotEmpty) {
      await prefs.setString("espIp", espIp);
    }

    // Save OR info fields
    await prefs.setString("otNumber", _selectedOT ?? '');
    await prefs.setString("doctorName", _doctorController.text.trim());
    await prefs.setString("patientName", _patientController.text.trim());
    await prefs.setString("surgeryName", _surgeryController.text.trim());

    Widget nextScreen;
    switch (_selectedMode) {
      case 'Main':
        nextScreen = Home();
        break;
      case 'Entrance':
        nextScreen = ORStatusMonitor();
        break;
      case 'Passage':
        nextScreen = Home();
        break;
      case 'Bronchi':
        nextScreen = Home();
        break;
      default:
        nextScreen = Home();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  bool _isValidIpAddress(String ip) {
    final RegExp ipRegex = RegExp(
      r'^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    return ipRegex.hasMatch(ip);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _espIpController.dispose();
    _doctorController.dispose();
    _patientController.dispose();
    _surgeryController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.blueGrey),
      prefixIcon: Icon(icon, color: Colors.blueGrey),
      filled: true,
      fillColor: const Color.fromARGB(142, 255, 255, 255),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset("assets/bgi.jpg", fit: BoxFit.cover),

          // Semi-transparent overlay
          Container(color: Colors.black.withOpacity(0.4)),

          // Login Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                color: Colors.white.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 12,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "LOGIN WITH WIESPL",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(184, 255, 255, 255),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // ── Unique Code ──────────────────────────────────
                        TextField(
                          controller: _codeController,
                          style: const TextStyle(color: Colors.black),
                          decoration: _fieldDecoration(
                            label: "Enter Unique Code",
                            icon: Icons.vpn_key,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── ESP32 IP ─────────────────────────────────────
                        TextField(
                          controller: _espIpController,
                          style: const TextStyle(color: Colors.black),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          decoration: _fieldDecoration(
                            label: "ESP32 IP Address",
                            icon: Icons.settings_ethernet,
                            hint: "192.168.4.1",
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── OT Number Dropdown ───────────────────────────
                        DropdownButtonFormField<String>(
                          value: _selectedOT,
                          style: const TextStyle(color: Colors.black),
                          items: _otNumbers
                              .map(
                                (ot) => DropdownMenuItem(
                                  value: ot,
                                  child: Text(
                                    ot,
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) => setState(() => _selectedOT = val),
                          decoration: InputDecoration(
                            labelText: "Select OT Number",
                            labelStyle: const TextStyle(color: Colors.blueGrey),
                            prefixIcon: const Icon(
                              Icons.meeting_room_outlined,
                              color: Colors.blueGrey,
                            ),
                            filled: true,
                            fillColor: const Color.fromARGB(158, 255, 255, 255),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Doctor Name ──────────────────────────────────
                        // TextField(
                        //   controller: _doctorController,
                        //   style: const TextStyle(color: Colors.black),
                        //   decoration: _fieldDecoration(
                        //     label: "Doctor Name",
                        //     icon: Icons.medical_services_outlined,
                        //   ),
                        // ),
                        // const SizedBox(height: 20),

                        // ── Patient Name ─────────────────────────────────
                        // TextField(
                        //   controller: _patientController,
                        //   style: const TextStyle(color: Colors.black),
                        //   decoration: _fieldDecoration(
                        //     label: "Patient Name",
                        //     icon: Icons.person_outline,
                        //   ),
                        // ),
                        // const SizedBox(height: 20),

                        // ── Surgery Name ─────────────────────────────────
                        // TextField(
                        //   controller: _surgeryController,
                        //   style: const TextStyle(color: Colors.black),
                        //   decoration: _fieldDecoration(
                        //     label: "Surgery Name",
                        //     icon: Icons.local_hospital_outlined,
                        //   ),
                        // ),
                        // const SizedBox(height: 20),

                        // ── Mode Dropdown ────────────────────────────────
                        DropdownButtonFormField<String>(
                          value: _selectedMode,
                          style: const TextStyle(color: Colors.black),
                          items: _modes
                              .map(
                                (mode) => DropdownMenuItem(
                                  value: mode,
                                  child: Text(
                                    mode,
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedMode = val),
                          decoration: InputDecoration(
                            labelText: "Select Mode",
                            labelStyle: const TextStyle(color: Colors.blueGrey),
                            prefixIcon: const Icon(
                              Icons.settings_applications_outlined,
                              color: Colors.blueGrey,
                            ),
                            filled: true,
                            fillColor: const Color.fromARGB(158, 255, 255, 255),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // ── Login Button ─────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _onLogin,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: const Color.fromARGB(
                                234,
                                0,
                                0,
                                0,
                              ),
                            ),
                            child: const Text(
                              "Login",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(221, 255, 255, 255),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
// import 'package:flutter/material.dart';
// import 'dart:ui';
// import 'dart:async';
// import 'dart:math' as math;
// import 'package:provider/provider.dart';
// import 'package:flutter_animate/flutter_animate.dart';

// void main() => runApp(
//   ChangeNotifierProvider(
//     create: (_) => ORSystemProvider(),
//     child: MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData.dark(),
//       home: DigitalORScreen(),
//     ),
//   ),
// );

// // --- STATE MANAGEMENT ---
// class ORSystemProvider extends ChangeNotifier {
//   int _activeIndex = 0;
//   double _temp = 22.5;
//   double _rh = 48.0;
//   double _light = 80.0;
//   int _seconds = 0;
//   Timer? _timer;
//   bool _timerRunning = false;
//   bool _isPlaying = false;
//   double _oxygenPressure = 4.2;

//   int get activeIndex => _activeIndex;
//   double get temp => _temp;
//   double get rh => _rh;
//   double get light => _light;
//   bool get timerRunning => _timerRunning;
//   bool get isPlaying => _isPlaying;
//   double get oxygenPressure => _oxygenPressure;

//   String get stopwatchTime {
//     Duration d = Duration(seconds: _seconds);
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
//   }

//   void updateIndex(int index) {
//     _activeIndex = index;
//     notifyListeners();
//   }

//   void updateTemp(double val) {
//     _temp = val;
//     notifyListeners();
//   }

//   void updateRH(double val) {
//     _rh = val;
//     notifyListeners();
//   }

//   void updateLight(double val) {
//     _light = val;
//     notifyListeners();
//   }

//   void updateMGPS(double val) {
//     _oxygenPressure = val;
//     notifyListeners();
//   }

//   void toggleMusic() {
//     _isPlaying = !_isPlaying;
//     notifyListeners();
//   }

//   void toggleTimer() {
//     _timerRunning = !_timerRunning;
//     if (_timerRunning) {
//       _timer = Timer.periodic(const Duration(seconds: 1), (t) {
//         _seconds++;
//         notifyListeners();
//       });
//     } else {
//       _timer?.cancel();
//     }
//     notifyListeners();
//   }

//   void resetTimer() {
//     _timer?.cancel();
//     _timerRunning = false;
//     _seconds = 0;
//     notifyListeners();
//   }
// }

// class DigitalORScreen extends StatelessWidget {
//   final List<Map<String, dynamic>> menuItems = [
//     {'name': 'Temp', 'icon': Icons.thermostat, 'color': Colors.cyanAccent},
//     {'name': 'RH', 'icon': Icons.water_drop, 'color': Colors.blueAccent},
//     {'name': 'Lighting', 'icon': Icons.wb_sunny, 'color': Colors.amberAccent},
//     {'name': 'Stop Watch', 'icon': Icons.timer, 'color': Colors.redAccent},
//     {'name': 'Music', 'icon': Icons.music_note, 'color': Colors.purpleAccent},
//     {'name': 'MGPS', 'icon': Icons.gas_meter, 'color': Colors.greenAccent},
//   ];

//   @override
//   Widget build(BuildContext context) {
//     var pro = Provider.of<ORSystemProvider>(context);

//     return Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: RadialGradient(
//             center: Alignment.center,
//             radius: 1.2,
//             colors: [Color(0xFF1A4A54), Color(0xFF050F14)],
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               _buildHeader(),
//               Expanded(
//                 child: LayoutBuilder(
//                   builder: (context, constraints) {
//                     double diameter =
//                         math.min(constraints.maxWidth, constraints.maxHeight) *
//                         0.80;
//                     return Stack(
//                       alignment: Alignment.center,
//                       children: [
//                         // Orbit Ring
//                         Container(
//                           width: diameter,
//                           height: diameter,
//                           decoration: BoxDecoration(
//                             shape: BoxShape.circle,
//                             border: Border.all(color: Colors.white10, width: 2),
//                           ),
//                         ),

//                         // Large Center Interactive Area
//                         SizedBox(
//                           width: diameter * 0.58,
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               _buildCenterDisplay(pro),
//                               const SizedBox(height: 12),
//                               _buildInCircleControls(context, pro),
//                             ],
//                           ),
//                         ),

//                         // MENU ICONS WITH BIG NUMBERS
//                         ...List.generate(menuItems.length, (index) {
//                           double angle =
//                               (index * 360 / menuItems.length - 90) *
//                               (math.pi / 180);
//                           double x = (diameter / 2) * math.cos(angle);
//                           double y = (diameter / 2) * math.sin(angle);

//                           return Transform.translate(
//                             offset: Offset(x, y),
//                             child: _buildLiveCircularButton(index, pro),
//                           );
//                         }),
//                       ],
//                     );
//                   },
//                 ),
//               ),
//               const SizedBox(height: 10),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildLiveCircularButton(int index, ORSystemProvider pro) {
//     bool isActive = pro.activeIndex == index;
//     var item = menuItems[index];

//     // Logic for Large Text Values inside icons
//     String liveVal = "";
//     if (index == 0) liveVal = "${pro.temp.toStringAsFixed(0)}°"; // e.g. 23°
//     if (index == 1) liveVal = "${pro.rh.toInt()}%"; // e.g. 48%
//     if (index == 5) liveVal = pro.oxygenPressure.toStringAsFixed(1); // e.g. 4.2

//     return GestureDetector(
//       onTap: () => pro.updateIndex(index),
//       child: AnimatedContainer(
//         duration: 250.ms,
//         width: isActive ? 95 : 80, // Larger base size
//         height: isActive ? 95 : 80,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           color: isActive
//               ? (item['color'] as Color).withOpacity(0.3)
//               : Colors.black.withOpacity(0.7),
//           border: Border.all(
//             color: isActive ? item['color'] : Colors.white24,
//             width: isActive ? 4 : 2,
//           ),
//           boxShadow: [
//             if (isActive)
//               BoxShadow(
//                 color: (item['color'] as Color).withOpacity(0.5),
//                 blurRadius: 25,
//               ),
//           ],
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               item['icon'],
//               size: isActive ? 28 : 24,
//               color: isActive ? item['color'] : Colors.white70,
//             ),
//             if (liveVal.isNotEmpty)
//               Text(
//                 liveVal,
//                 style: const TextStyle(
//                   fontSize: 14, // INCREASED FONT SIZE
//                   fontWeight: FontWeight.w900, // EXTRA BOLD
//                   color: Colors.white,
//                   letterSpacing: -0.5,
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCenterDisplay(ORSystemProvider pro) {
//     String value = "";
//     switch (pro.activeIndex) {
//       case 0:
//         value = "${pro.temp.toStringAsFixed(1)}°C";
//         break;
//       case 1:
//         value = "${pro.rh.toInt()}%";
//         break;
//       case 2:
//         value = "${pro.light.toInt()}%";
//         break;
//       case 3:
//         value = pro.stopwatchTime;
//         break;
//       case 4:
//         value = pro.isPlaying ? "PLAYING" : "PAUSED";
//         break;
//       case 5:
//         value = "${pro.oxygenPressure.toStringAsFixed(1)} BAR";
//         break;
//     }

//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Text(
//           menuItems[pro.activeIndex]['name'].toUpperCase(),
//           style: const TextStyle(
//             letterSpacing: 4,
//             color: Colors.white38,
//             fontSize: 12,
//           ),
//         ),
//         const SizedBox(height: 5),
//         Text(
//           value,
//           style: const TextStyle(
//             fontSize: 54,
//             fontWeight: FontWeight.w100,
//             color: Colors.white,
//           ),
//         ),
//       ],
//     ).animate(key: ValueKey(pro.activeIndex)).fadeIn();
//   }

//   Widget _buildInCircleControls(BuildContext context, ORSystemProvider pro) {
//     final activeColor = menuItems[pro.activeIndex]['color'];
//     switch (pro.activeIndex) {
//       case 3: // Stopwatch
//         return Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             IconButton(
//               onPressed: pro.toggleTimer,
//               icon: Icon(
//                 pro.timerRunning ? Icons.pause_circle : Icons.play_circle,
//                 color: activeColor,
//                 size: 48,
//               ),
//             ),
//             IconButton(
//               onPressed: pro.resetTimer,
//               icon: const Icon(Icons.refresh, color: Colors.white30, size: 30),
//             ),
//           ],
//         );
//       case 4: // Music
//         return IconButton(
//           icon: Icon(
//             pro.isPlaying
//                 ? Icons.pause_circle_filled
//                 : Icons.play_circle_filled,
//             size: 50,
//             color: activeColor,
//           ),
//           onPressed: pro.toggleMusic,
//         );
//       default: // Sliders
//         return SliderTheme(
//           data: SliderTheme.of(context).copyWith(
//             trackHeight: 4,
//             thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
//             activeTrackColor: activeColor,
//             thumbColor: Colors.white,
//           ),
//           child: Slider(
//             value: _getValue(pro),
//             min: _getBounds(pro.activeIndex)[0],
//             max: _getBounds(pro.activeIndex)[1],
//             onChanged: (v) => _updateValue(pro, v),
//           ),
//         );
//     }
//   }

//   double _getValue(ORSystemProvider pro) {
//     if (pro.activeIndex == 0) return pro.temp;
//     if (pro.activeIndex == 1) return pro.rh;
//     if (pro.activeIndex == 2) return pro.light;
//     return pro.oxygenPressure;
//   }

//   List<double> _getBounds(int i) {
//     if (i == 0) return [16, 30];
//     if (i == 1) return [20, 80];
//     if (i == 5) return [3.0, 6.0];
//     return [0, 100];
//   }

//   void _updateValue(ORSystemProvider pro, double v) {
//     if (pro.activeIndex == 0) pro.updateTemp(v);
//     if (pro.activeIndex == 1) pro.updateRH(v);
//     if (pro.activeIndex == 2) pro.updateLight(v);
//     if (pro.activeIndex == 5) pro.updateMGPS(v);
//   }

//   Widget _buildHeader() {
//     return const Padding(
//       padding: EdgeInsets.all(25),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             "19:30",
//             style: TextStyle(fontSize: 22, fontWeight: FontWeight.w200),
//           ),
//           Text(
//             "DIGITAL OR SYSTEM",
//             style: TextStyle(
//               letterSpacing: 2,
//               fontWeight: FontWeight.bold,
//               fontSize: 12,
//             ),
//           ),
//           CircleAvatar(
//             backgroundColor: Colors.white10,
//             radius: 15,
//             child: Icon(Icons.person, size: 14),
//           ),
//         ],
//       ),
//     );
//   }
// }
// import 'package:flutter/material.dart';
// import 'package:flutter_vlc_player/flutter_vlc_player.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'dart:io';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Stream Recorder',
//       theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
//       home: const StreamRecorderPage(),
//     );
//   }
// }

// class StreamRecorderPage extends StatefulWidget {
//   const StreamRecorderPage({Key? key}) : super(key: key);

//   @override
//   State<StreamRecorderPage> createState() => _StreamRecorderPageState();
// }

// class _StreamRecorderPageState extends State<StreamRecorderPage> {
//   late VlcPlayerController _videoPlayerController;
//   bool _isRecording = false;
//   bool _isInitialized = false;
//   String? _recordingPath;
//   final String _streamUrl = 'http://192.168.0.12:9081/';

//   @override
//   void initState() {
//     super.initState();
//     _requestPermissions();
//     _initializePlayer();
//   }

//   Future<void> _requestPermissions() async {
//     if (Platform.isAndroid) {
//       await Permission.storage.request();
//       if (await Permission.storage.isDenied) {
//         await Permission.manageExternalStorage.request();
//       }
//     }
//   }

//   Future<void> _initializePlayer() async {
//     _videoPlayerController = VlcPlayerController.network(
//       _streamUrl,
//       hwAcc: HwAcc.full,
//       autoPlay: true,
//       options: VlcPlayerOptions(
//         advanced: VlcAdvancedOptions([VlcAdvancedOptions.networkCaching(2000)]),
//         video: VlcVideoOptions([
//           VlcVideoOptions.dropLateFrames(true),
//           VlcVideoOptions.skipFrames(true),
//         ]),
//         rtp: VlcRtpOptions([VlcRtpOptions.rtpOverRtsp(true)]),
//       ),
//     );

//     await _videoPlayerController.initialize();
//     setState(() {
//       _isInitialized = true;
//     });
//   }

//   Future<void> _startRecording() async {
//     try {
//       final directory = Platform.isAndroid
//           ? await getExternalStorageDirectory()
//           : await getApplicationDocumentsDirectory();

//       if (directory == null) {
//         _showMessage('Failed to get storage directory');
//         return;
//       }

//       final timestamp = DateTime.now().millisecondsSinceEpoch;
//       final recordingDir = Directory('${directory.path}/Recordings');

//       if (!await recordingDir.exists()) {
//         await recordingDir.create(recursive: true);
//       }

//       _recordingPath = '${recordingDir.path}/recording_$timestamp.mp4';

//       final success = await _videoPlayerController.startRecording(
//         _recordingPath!,
//       );

//       if (success == true) {
//         setState(() {
//           _isRecording = true;
//         });
//         _showMessage('Recording started: $_recordingPath');
//       } else {
//         _showMessage('Failed to start recording');
//       }
//     } catch (e) {
//       _showMessage('Error starting recording: $e');
//     }
//   }

//   Future<void> _stopRecording() async {
//     try {
//       final success = await _videoPlayerController.stopRecording();

//       if (success == true) {
//         setState(() {
//           _isRecording = false;
//         });
//         _showMessage('Recording saved: $_recordingPath');
//       } else {
//         _showMessage('Failed to stop recording');
//       }
//     } catch (e) {
//       _showMessage('Error stopping recording: $e');
//     }
//   }

//   void _showMessage(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
//     );
//   }

//   @override
//   void dispose() {
//     _videoPlayerController.stopRecording();
//     _videoPlayerController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Stream Recorder'), elevation: 2),
//       body: Column(
//         children: [
//           Expanded(
//             child: _isInitialized
//                 ? VlcPlayer(
//                     controller: _videoPlayerController,
//                     aspectRatio: 16 / 9,
//                     placeholder: const Center(
//                       child: CircularProgressIndicator(),
//                     ),
//                   )
//                 : const Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         CircularProgressIndicator(),
//                         SizedBox(height: 16),
//                         Text('Connecting to stream...'),
//                       ],
//                     ),
//                   ),
//           ),
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.grey[100],
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.1),
//                   blurRadius: 4,
//                   offset: const Offset(0, -2),
//                 ),
//               ],
//             ),
//             child: Column(
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     ElevatedButton.icon(
//                       onPressed: _isRecording ? null : _startRecording,
//                       icon: const Icon(Icons.fiber_manual_record),
//                       label: const Text('Start Recording'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.red,
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 20,
//                           vertical: 12,
//                         ),
//                       ),
//                     ),
//                     ElevatedButton.icon(
//                       onPressed: _isRecording ? _stopRecording : null,
//                       icon: const Icon(Icons.stop),
//                       label: const Text('Stop Recording'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.grey[700],
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 20,
//                           vertical: 12,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 12),
//                 if (_isRecording)
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Container(
//                         width: 12,
//                         height: 12,
//                         decoration: const BoxDecoration(
//                           color: Colors.red,
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       const Text(
//                         'Recording in progress...',
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: Colors.red,
//                         ),
//                       ),
//                     ],
//                   ),
//                 if (_recordingPath != null && !_isRecording)
//                   Text(
//                     'Last recording: ${_recordingPath!.split('/').last}',
//                     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
// // import 'package:flutter/material.dart';
// // import 'package:webview_flutter/webview_flutter.dart';
// // import 'package:path_provider/path_provider.dart';
// // import 'package:permission_handler/permission_handler.dart';
// // import 'package:dio/dio.dart';
// // import 'package:share_plus/share_plus.dart';
// // import 'package:video_player/video_player.dart';
// // import 'package:chewie/chewie.dart';
// // import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
// // import 'package:ffmpeg_kit_flutter_new/return_code.dart';
// // import 'dart:io';
// // import 'dart:async';

// // void main() {
// //   runApp(const MyApp());
// // }

// // class MyApp extends StatelessWidget {
// //   const MyApp({Key? key}) : super(key: key);

// //   @override
// //   Widget build(BuildContext context) {
// //     return MaterialApp(
// //       title: 'Stream Recorder Pro',
// //       theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
// //       home: const StreamRecorderPage(),
// //       debugShowCheckedModeBanner: false,
// //     );
// //   }
// // }

// // // --- Video Player Screen ---
// // class VideoPlayerScreen extends StatefulWidget {
// //   final String filePath;
// //   final String fileName;

// //   const VideoPlayerScreen({
// //     Key? key,
// //     required this.filePath,
// //     required this.fileName,
// //   }) : super(key: key);

// //   @override
// //   State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
// // }

// // class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
// //   late VideoPlayerController _videoController;
// //   ChewieController? _chewieController;
// //   bool _isInitialized = false;
// //   String? _error;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _initializePlayer();
// //   }

// //   Future<void> _initializePlayer() async {
// //     try {
// //       _videoController = VideoPlayerController.file(File(widget.filePath));
// //       await _videoController.initialize();

// //       _chewieController = ChewieController(
// //         videoPlayerController: _videoController,
// //         autoPlay: true,
// //         looping: false,
// //         aspectRatio: _videoController.value.aspectRatio,
// //         allowFullScreen: true,
// //         allowMuting: true,
// //         showControls: true,
// //         materialProgressColors: ChewieProgressColors(
// //           playedColor: Colors.red,
// //           handleColor: Colors.redAccent,
// //           backgroundColor: Colors.grey,
// //           bufferedColor: Colors.lightGreen,
// //         ),
// //         errorBuilder: (context, errorMessage) {
// //           return Center(
// //             child: Padding(
// //               padding: const EdgeInsets.all(16.0),
// //               child: Column(
// //                 mainAxisAlignment: MainAxisAlignment.center,
// //                 children: [
// //                   const Icon(Icons.error_outline, color: Colors.red, size: 48),
// //                   const SizedBox(height: 16),
// //                   Text(
// //                     "Playback Error",
// //                     style: const TextStyle(
// //                       color: Colors.white,
// //                       fontSize: 18,
// //                       fontWeight: FontWeight.bold,
// //                     ),
// //                   ),
// //                   const SizedBox(height: 8),
// //                   Text(
// //                     errorMessage,
// //                     style: const TextStyle(color: Colors.white70),
// //                     textAlign: TextAlign.center,
// //                   ),
// //                   const SizedBox(height: 16),
// //                   const Text(
// //                     "Your device may not support this resolution.\nTry playing on a computer or use VLC player.",
// //                     style: TextStyle(color: Colors.white60, fontSize: 12),
// //                     textAlign: TextAlign.center,
// //                   ),
// //                   const SizedBox(height: 16),
// //                   ElevatedButton.icon(
// //                     onPressed: () => Navigator.pop(context),
// //                     icon: const Icon(Icons.arrow_back),
// //                     label: const Text("Go Back"),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           );
// //         },
// //       );

// //       setState(() => _isInitialized = true);
// //     } catch (e) {
// //       setState(() => _error = e.toString());
// //     }
// //   }

// //   @override
// //   void dispose() {
// //     _videoController.dispose();
// //     _chewieController?.dispose();
// //     super.dispose();
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: Colors.black,
// //       appBar: AppBar(
// //         title: Text(widget.fileName),
// //         backgroundColor: Colors.black,
// //         foregroundColor: Colors.white,
// //       ),
// //       body: Center(
// //         child: _error != null
// //             ? Text(
// //                 "Error: $_error",
// //                 style: const TextStyle(color: Colors.white),
// //               )
// //             : _isInitialized
// //             ? Chewie(controller: _chewieController!)
// //             : const CircularProgressIndicator(),
// //       ),
// //     );
// //   }
// // }

// // // --- Main Recorder Page ---
// // class StreamRecorderPage extends StatefulWidget {
// //   const StreamRecorderPage({Key? key}) : super(key: key);

// //   @override
// //   State<StreamRecorderPage> createState() => _StreamRecorderPageState();
// // }

// // class _StreamRecorderPageState extends State<StreamRecorderPage> {
// //   late WebViewController _webViewController;
// //   bool _isRecording = false;
// //   bool _isLoading = true;
// //   bool _isConverting = false;
// //   String? _recordingPath;

// //   // Updated to include resolution parameters for 4K
// //   final String _baseUrl = 'http://192.168.1.115:9082/';
// //   String _streamUrl =
// //       'http://192.168.1.115:9082/?action=stream&width=3840&height=2160';

// //   CancelToken? _cancelToken;
// //   IOSink? _fileSink;
// //   int _bytesDownloaded = 0;
// //   DateTime? _recordingStartTime;
// //   Timer? _uiTimer;
// //   double _conversionProgress = 0.0;

// //   // Resolution settings
// //   String _selectedResolution = '4K (3840x2160)';
// //   final Map<String, Map<String, int>> _resolutions = {
// //     '4K (3840x2160)': {'width': 3840, 'height': 2160},
// //     'QHD (2560x1440)': {'width': 2560, 'height': 1440},
// //     'FHD (1920x1080)': {'width': 1920, 'height': 1080},
// //     'HD (1280x720)': {'width': 1280, 'height': 720},
// //   };

// //   @override
// //   void initState() {
// //     super.initState();
// //     _requestPermissions();
// //     _initializeWebView();
// //   }

// //   Future<void> _requestPermissions() async {
// //     await [
// //       Permission.storage,
// //       Permission.manageExternalStorage,
// //       Permission.camera,
// //     ].request();
// //   }

// //   void _initializeWebView() {
// //     _webViewController = WebViewController()
// //       ..setJavaScriptMode(JavaScriptMode.unrestricted)
// //       ..setBackgroundColor(Colors.black)
// //       ..setNavigationDelegate(
// //         NavigationDelegate(
// //           onPageStarted: (_) => setState(() => _isLoading = true),
// //           onPageFinished: (_) => setState(() => _isLoading = false),
// //         ),
// //       )
// //       ..loadRequest(Uri.parse(_streamUrl));
// //   }

// //   void _updateResolution(String resolution) {
// //     setState(() {
// //       _selectedResolution = resolution;
// //       final res = _resolutions[resolution]!;
// //       _streamUrl =
// //           '$_baseUrl?action=stream&width=${res['width']}&height=${res['height']}';
// //       _webViewController.loadRequest(Uri.parse(_streamUrl));
// //     });
// //   }

// //   Future<void> _startRecording() async {
// //     try {
// //       final directory = Platform.isAndroid
// //           ? await getExternalStorageDirectory()
// //           : await getApplicationDocumentsDirectory();

// //       if (directory == null) return;

// //       final recordingDir = Directory('${directory.path}/Recordings');
// //       if (!await recordingDir.exists())
// //         await recordingDir.create(recursive: true);

// //       final timestamp = DateTime.now().millisecondsSinceEpoch;
// //       final res = _resolutions[_selectedResolution]!;
// //       _recordingPath =
// //           '${recordingDir.path}/rec_${res['width']}x${res['height']}_$timestamp.mjpeg';

// //       _fileSink = File(_recordingPath!).openWrite();
// //       _cancelToken = CancelToken();
// //       _bytesDownloaded = 0;
// //       _recordingStartTime = DateTime.now();

// //       setState(() => _isRecording = true);

// //       // Start UI Timer to update duration every second
// //       _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
// //         if (mounted) setState(() {});
// //       });

// //       final dio = Dio();
// //       final response = await dio.get(
// //         _streamUrl,
// //         options: Options(
// //           responseType: ResponseType.stream,
// //           headers: {'Connection': 'keep-alive'},
// //         ),
// //         cancelToken: _cancelToken,
// //       );

// //       await for (List<int> chunk in response.data.stream) {
// //         if (_cancelToken?.isCancelled ?? true) break;
// //         _fileSink?.add(chunk);
// //         _bytesDownloaded += chunk.length;
// //       }
// //     } catch (e) {
// //       if (!(_cancelToken?.isCancelled ?? false)) {
// //         _showMessage('Error: $e');
// //         _stopRecording();
// //       }
// //     }
// //   }

// //   Future<void> _stopRecording() async {
// //     _uiTimer?.cancel();
// //     _cancelToken?.cancel();
// //     await _fileSink?.flush();
// //     await _fileSink?.close();
// //     _fileSink = null;

// //     setState(() {
// //       _isRecording = false;
// //     });

// //     if (_recordingPath != null) {
// //       await _convertToMp4(_recordingPath!);
// //     }
// //   }

// //   Future<void> _convertToMp4(String mjpegPath) async {
// //     setState(() {
// //       _isConverting = true;
// //       _conversionProgress = 0.0;
// //     });

// //     final mp4Path = mjpegPath.replaceAll('.mjpeg', '.mp4');

// //     // Enhanced FFmpeg command with H.264 profile compatible with most devices
// //     // Using baseline profile level 5.1 for better compatibility
// //     final command =
// //         '-i "$mjpegPath" -c:v libx264 -profile:v high -level 5.1 -preset fast -crf 23 -pix_fmt yuv420p -movflags +faststart -max_muxing_queue_size 1024 -y "$mp4Path"';

// //     await FFmpegKit.executeAsync(
// //       command,
// //       (session) async {
// //         final returnCode = await session.getReturnCode();
// //         setState(() => _isConverting = false);

// //         if (ReturnCode.isSuccess(returnCode)) {
// //           File(mjpegPath).delete().catchError((e) => print(e));
// //           _showMessage('Saved: ${mp4Path.split('/').last}');

// //           // Optionally create a mobile-friendly version
// //           if (_selectedResolution == '4K (3840x2160)') {
// //             _showCreateMobileVersion(mp4Path);
// //           }
// //         } else {
// //           final logs = await session.getOutput();
// //           _showMessage('MP4 conversion failed. Check logs.');
// //           print('FFmpeg error: $logs');
// //         }
// //       },
// //       null,
// //       (stats) {
// //         setState(
// //           () => _conversionProgress = stats.getTime().toDouble() / 1000.0,
// //         );
// //       },
// //     );
// //   }

// //   void _showCreateMobileVersion(String originalPath) {
// //     showDialog(
// //       context: context,
// //       builder: (context) => AlertDialog(
// //         title: const Text('Create Mobile Version?'),
// //         content: const Text(
// //           'High-resolution videos may not play on all devices.\n\n'
// //           'Create a 1080p version for mobile playback?\n'
// //           '(Original 4K file will be kept)',
// //         ),
// //         actions: [
// //           TextButton(
// //             onPressed: () => Navigator.pop(context),
// //             child: const Text('No'),
// //           ),
// //           ElevatedButton(
// //             onPressed: () {
// //               Navigator.pop(context);
// //               _createMobileVersion(originalPath);
// //             },
// //             child: const Text('Yes, Create'),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Future<void> _createMobileVersion(String originalPath) async {
// //     setState(() {
// //       _isConverting = true;
// //       _conversionProgress = 0.0;
// //     });

// //     final mobilePath = originalPath.replaceAll('.mp4', '_mobile.mp4');

// //     // Scale down to 1080p with optimized settings for mobile
// //     final command =
// //         '-i "$originalPath" -vf "scale=1920:1080:force_original_aspect_ratio=decrease" '
// //         '-c:v libx264 -profile:v main -level 4.1 -preset fast -crf 23 -pix_fmt yuv420p '
// //         '-movflags +faststart -y "$mobilePath"';

// //     await FFmpegKit.executeAsync(
// //       command,
// //       (session) async {
// //         final returnCode = await session.getReturnCode();
// //         setState(() => _isConverting = false);

// //         if (ReturnCode.isSuccess(returnCode)) {
// //           _showMessage('Mobile version created: ${mobilePath.split('/').last}');
// //         } else {
// //           _showMessage('Failed to create mobile version');
// //         }
// //       },
// //       null,
// //       (stats) {
// //         setState(
// //           () => _conversionProgress = stats.getTime().toDouble() / 1000.0,
// //         );
// //       },
// //     );
// //   }

// //   // --- UI Helpers ---

// //   String _getDuration() {
// //     if (_recordingStartTime == null) return "00:00";
// //     final diff = DateTime.now().difference(_recordingStartTime!);
// //     return "${diff.inMinutes.toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
// //   }

// //   void _showMessage(String msg) {
// //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
// //   }

// //   String _formatBytes(int bytes) {
// //     if (bytes < 1024) return '$bytes B';
// //     if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
// //     return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
// //   }

// //   Future<List<FileSystemEntity>> _getFiles() async {
// //     final directory = Platform.isAndroid
// //         ? await getExternalStorageDirectory()
// //         : await getApplicationDocumentsDirectory();
// //     final recordingDir = Directory('${directory!.path}/Recordings');
// //     if (!await recordingDir.exists()) return [];
// //     return recordingDir
// //         .listSync()
// //         .where((f) => f.path.endsWith('.mp4') || f.path.endsWith('.mjpeg'))
// //         .toList();
// //   }

// //   void _showRecordingsList() async {
// //     final files = await _getFiles();
// //     if (!mounted) return;
// //     showModalBottomSheet(
// //       context: context,
// //       builder: (ctx) => Column(
// //         children: [
// //           Padding(
// //             padding: const EdgeInsets.all(16.0),
// //             child: Row(
// //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //               children: [
// //                 const Text(
// //                   'Recordings',
// //                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
// //                 ),
// //                 TextButton.icon(
// //                   onPressed: () => _showPlaybackHelp(ctx),
// //                   icon: const Icon(Icons.help_outline, size: 18),
// //                   label: const Text('Help'),
// //                 ),
// //               ],
// //             ),
// //           ),
// //           Expanded(
// //             child: files.isEmpty
// //                 ? const Center(child: Text('No recordings yet'))
// //                 : ListView.builder(
// //                     itemCount: files.length,
// //                     itemBuilder: (ctx, i) {
// //                       final fileName = files[i].path.split('/').last;
// //                       final fileSize = File(files[i].path).lengthSync();

// //                       return ListTile(
// //                         leading: const Icon(Icons.movie, color: Colors.red),
// //                         title: Text(
// //                           fileName,
// //                           style: const TextStyle(fontSize: 12),
// //                         ),
// //                         subtitle: Text(
// //                           _formatBytes(fileSize),
// //                           style: const TextStyle(fontSize: 10),
// //                         ),
// //                         trailing: Row(
// //                           mainAxisSize: MainAxisSize.min,
// //                           children: [
// //                             IconButton(
// //                               icon: const Icon(Icons.play_arrow),
// //                               onPressed: () {
// //                                 Navigator.pop(ctx);
// //                                 Navigator.push(
// //                                   context,
// //                                   MaterialPageRoute(
// //                                     builder: (_) => VideoPlayerScreen(
// //                                       filePath: files[i].path,
// //                                       fileName: fileName,
// //                                     ),
// //                                   ),
// //                                 );
// //                               },
// //                             ),
// //                             IconButton(
// //                               icon: const Icon(Icons.delete, color: Colors.red),
// //                               onPressed: () {
// //                                 _deleteFile(files[i].path);
// //                                 Navigator.pop(ctx);
// //                               },
// //                             ),
// //                           ],
// //                         ),
// //                       );
// //                     },
// //                   ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   void _showPlaybackHelp(BuildContext ctx) {
// //     showDialog(
// //       context: ctx,
// //       builder: (context) => AlertDialog(
// //         title: const Text('Playback Issues?'),
// //         content: const Text(
// //           'If videos won\'t play on your device:\n\n'
// //           '1. High-resolution videos may exceed device capabilities\n'
// //           '2. Transfer files to a computer for playback\n'
// //           '3. Use VLC Media Player (supports all resolutions)\n'
// //           '4. Try recording at a lower resolution (HD or FHD)\n\n'
// //           'The files are saved as standard MP4 videos.',
// //         ),
// //         actions: [
// //           TextButton(
// //             onPressed: () => Navigator.pop(context),
// //             child: const Text('OK'),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Future<void> _deleteFile(String path) async {
// //     try {
// //       await File(path).delete();
// //       _showMessage('Recording deleted');
// //     } catch (e) {
// //       _showMessage('Failed to delete: $e');
// //     }
// //   }

// //   void _showResolutionPicker() {
// //     showModalBottomSheet(
// //       context: context,
// //       builder: (ctx) => ListView(
// //         children: _resolutions.keys.map((resolution) {
// //           return ListTile(
// //             title: Text(resolution),
// //             trailing: _selectedResolution == resolution
// //                 ? const Icon(Icons.check, color: Colors.green)
// //                 : null,
// //             onTap: () {
// //               Navigator.pop(ctx);
// //               _updateResolution(resolution);
// //             },
// //           );
// //         }).toList(),
// //       ),
// //     );
// //   }

// //   @override
// //   void dispose() {
// //     _uiTimer?.cancel();
// //     super.dispose();
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text('Stream Recorder'),
// //         actions: [
// //           IconButton(
// //             icon: const Icon(Icons.settings),
// //             onPressed: _showResolutionPicker,
// //             tooltip: 'Resolution',
// //           ),
// //           IconButton(
// //             icon: const Icon(Icons.folder),
// //             onPressed: _showRecordingsList,
// //           ),
// //           IconButton(
// //             icon: const Icon(Icons.refresh),
// //             onPressed: () => _webViewController.reload(),
// //           ),
// //         ],
// //       ),
// //       body: Column(
// //         children: [
// //           // Resolution indicator
// //           Container(
// //             width: double.infinity,
// //             padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
// //             color: Colors.blue.shade700,
// //             child: Text(
// //               'Resolution: $_selectedResolution',
// //               style: const TextStyle(
// //                 color: Colors.white,
// //                 fontWeight: FontWeight.bold,
// //               ),
// //               textAlign: TextAlign.center,
// //             ),
// //           ),
// //           Expanded(
// //             child: Stack(
// //               children: [
// //                 WebViewWidget(controller: _webViewController),
// //                 if (_isLoading)
// //                   const Center(child: CircularProgressIndicator()),
// //                 if (_isRecording)
// //                   Positioned(
// //                     top: 20,
// //                     left: 20,
// //                     child: Container(
// //                       padding: const EdgeInsets.all(8),
// //                       decoration: BoxDecoration(
// //                         color: Colors.black87,
// //                         borderRadius: BorderRadius.circular(8),
// //                       ),
// //                       child: Column(
// //                         crossAxisAlignment: CrossAxisAlignment.start,
// //                         children: [
// //                           Row(
// //                             children: [
// //                               Container(
// //                                 width: 12,
// //                                 height: 12,
// //                                 decoration: const BoxDecoration(
// //                                   color: Colors.red,
// //                                   shape: BoxShape.circle,
// //                                 ),
// //                               ),
// //                               const SizedBox(width: 8),
// //                               Text(
// //                                 "REC ${_getDuration()}",
// //                                 style: const TextStyle(
// //                                   color: Colors.white,
// //                                   fontWeight: FontWeight.bold,
// //                                   fontSize: 16,
// //                                 ),
// //                               ),
// //                             ],
// //                           ),
// //                           const SizedBox(height: 4),
// //                           Text(
// //                             _formatBytes(_bytesDownloaded),
// //                             style: const TextStyle(
// //                               color: Colors.white70,
// //                               fontSize: 12,
// //                             ),
// //                           ),
// //                           Text(
// //                             _selectedResolution,
// //                             style: const TextStyle(
// //                               color: Colors.white70,
// //                               fontSize: 12,
// //                             ),
// //                           ),
// //                         ],
// //                       ),
// //                     ),
// //                   ),
// //               ],
// //             ),
// //           ),
// //           Padding(
// //             padding: const EdgeInsets.all(20),
// //             child: _isConverting
// //                 ? Column(
// //                     children: [
// //                       const LinearProgressIndicator(),
// //                       const SizedBox(height: 8),
// //                       Text(
// //                         "Converting to MP4... ${_conversionProgress.toStringAsFixed(1)}s",
// //                         style: const TextStyle(fontWeight: FontWeight.bold),
// //                       ),
// //                     ],
// //                   )
// //                 : Row(
// //                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// //                     children: [
// //                       ElevatedButton.icon(
// //                         onPressed: _isRecording ? null : _startRecording,
// //                         icon: const Icon(Icons.circle, color: Colors.red),
// //                         label: const Text("Start Recording"),
// //                         style: ElevatedButton.styleFrom(
// //                           padding: const EdgeInsets.symmetric(
// //                             horizontal: 24,
// //                             vertical: 12,
// //                           ),
// //                         ),
// //                       ),
// //                       ElevatedButton.icon(
// //                         onPressed: _isRecording ? _stopRecording : null,
// //                         icon: const Icon(Icons.stop),
// //                         label: const Text("Stop"),
// //                         style: ElevatedButton.styleFrom(
// //                           padding: const EdgeInsets.symmetric(
// //                             horizontal: 24,
// //                             vertical: 12,
// //                           ),
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
// import 'package:flutter/material.dart';
// import 'dart:async';
// import 'dart:math' as math;
// import 'dart:ui' as ui;
// import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:wiespl_surgeon_panel/temp/clll.dart';

// // --- ENUMS ---
// enum ScreenSize { mobile, tablet, desktop }

// enum ORViewMode { dashboard, orMode }

// // --- DATA MODELS ---
// class Patient {
//   final String id;
//   final String name;
//   final int age;
//   final String gender;
//   final String bloodGroup;
//   final String admissionDate;
//   final String diagnosis;
//   final String doctor;
//   final String roomNumber;
//   final String status;
//   final Map<String, dynamic>? vitals;
//   final List<String>? medications;
//   final List<String>? labResults;
//   final List<String>? imagingReports;

//   Patient({
//     required this.id,
//     required this.name,
//     required this.age,
//     required this.gender,
//     required this.bloodGroup,
//     required this.admissionDate,
//     required this.diagnosis,
//     required this.doctor,
//     required this.roomNumber,
//     required this.status,
//     this.vitals,
//     this.medications,
//     this.labResults,
//     this.imagingReports,
//   });

//   Color get statusColor {
//     switch (status.toLowerCase()) {
//       case 'critical':
//         return Colors.red;
//       case 'serious':
//         return Colors.orange;
//       case 'stable':
//         return Colors.green;
//       case 'discharged':
//         return Colors.blue;
//       default:
//         return Colors.grey;
//     }
//   }

//   IconData get statusIcon {
//     switch (status.toLowerCase()) {
//       case 'critical':
//         return Icons.warning;
//       case 'serious':
//         return Icons.error_outline;
//       case 'stable':
//         return Icons.check_circle;
//       case 'discharged':
//         return Icons.assignment_turned_in;
//       default:
//         return Icons.person;
//     }
//   }
// }

// void main() => runApp(
//   ChangeNotifierProvider(
//     create: (_) => ORSystemProvider(),
//     child: MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         brightness: Brightness.light,
//         fontFamily: 'Roboto',
//         primaryColor: const Color(0xFF00796B),
//       ),
//       home: const MedicalDashboard(),
//     ),
//   ),
// );

// // --- STATE MANAGEMENT ---
// class ORSystemProvider extends ChangeNotifier {
//   bool _isSystemOn = true;
//   double _temp = 22.5;
//   double _rh = 45.0;
//   DateTime _now = DateTime.now();

//   ORViewMode _viewMode = ORViewMode.dashboard;

//   bool _showMusic = false;
//   bool _showTempSettings = false;
//   bool _showHumiditySettings = false;
//   bool _showRightPanelFlip = false;
//   bool _showMGPSFlip = false;

//   final List<bool> _lights = [true, false, false, true];
//   int _seconds = 0;
//   Timer? _stopwatchTimer;
//   bool _timerRunning = false;

//   bool _isMusicPlaying = false;
//   int _currentTrackIndex = 0;
//   final AudioPlayer _audioPlayer = AudioPlayer();

//   final List<Map<String, dynamic>> _playlist = [
//     {"title": "He Ram He Ram", "asset": "assets/music/He Ram He Ram.mp3"},
//     {"title": "Mahamrityunjay Mantra", "asset": "assets/music/Mantra.mp3"},
//   ];

//   ORSystemProvider() {
//     Timer.periodic(const Duration(seconds: 1), (t) {
//       _now = DateTime.now();
//       notifyListeners();
//     });

//     _audioPlayer.playerStateStream.listen((playerState) {
//       _isMusicPlaying = playerState.playing;
//       if (playerState.processingState == ProcessingState.completed) nextTrack();
//       notifyListeners();
//     });
//   }

//   // Getters
//   bool get isSystemOn => _isSystemOn;
//   double get temp => _temp;
//   double get rh => _rh;
//   DateTime get now => _now;
//   bool get timerRunning => _timerRunning;
//   List<bool> get lights => _lights;
//   bool get showMusic => _showMusic;
//   bool get showTempSettings => _showTempSettings;
//   bool get showHumiditySettings => _showHumiditySettings;
//   bool get showRightPanelFlip => _showRightPanelFlip;
//   bool get showMGPSFlip => _showMGPSFlip;
//   bool get isMusicPlaying => _isMusicPlaying;
//   ORViewMode get viewMode => _viewMode;
//   String get currentTrack => _playlist[_currentTrackIndex]["title"];
//   String get formattedFullDate =>
//       DateFormat('EEEE, dd/MM/yyyy').format(_now).toUpperCase();

//   String get stopwatchDisplay {
//     Duration d = Duration(seconds: _seconds);
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds % 60)}";
//   }

//   // Set view mode
//   void setViewMode(ORViewMode mode) {
//     _viewMode = mode;
//     notifyListeners();
//   }

//   // Toggles
//   void toggleMusicFlip() {
//     _showMusic = !_showMusic;
//     notifyListeners();
//   }

//   void toggleTempFlip() {
//     _showTempSettings = !_showTempSettings;
//     notifyListeners();
//   }

//   void toggleHumidityFlip() {
//     _showHumiditySettings = !_showHumiditySettings;
//     notifyListeners();
//   }

//   void toggleRightPanelFlip() {
//     _showRightPanelFlip = !_showRightPanelFlip;
//     notifyListeners();
//   }

//   void toggleMGPSFlip() {
//     _showMGPSFlip = !_showMGPSFlip;
//     notifyListeners();
//   }

//   void adjustTemp(double delta) {
//     _temp += delta;
//     notifyListeners();
//   }

//   void adjustHumidity(double delta) {
//     _rh = (_rh + delta).clamp(0, 100);
//     notifyListeners();
//   }

//   Future<void> togglePlayPause() async {
//     if (_isMusicPlaying)
//       await _audioPlayer.pause();
//     else
//       await _playCurrentTrack();
//   }

//   Future<void> _playCurrentTrack() async {
//     try {
//       _isMusicPlaying = true;
//       notifyListeners();
//     } catch (e) {
//       debugPrint("Audio Error: $e");
//     }
//   }

//   void nextTrack() {
//     _currentTrackIndex = (_currentTrackIndex + 1) % _playlist.length;
//     _playCurrentTrack();
//   }

//   void prevTrack() {
//     _currentTrackIndex = (_currentTrackIndex - 1 < 0)
//         ? _playlist.length - 1
//         : _currentTrackIndex - 1;
//     _playCurrentTrack();
//   }

//   void toggleSystem() {
//     _isSystemOn = !_isSystemOn;
//     if (!_isSystemOn) {
//       _audioPlayer.stop();
//       resetStopwatch();
//     }
//     notifyListeners();
//   }

//   void toggleLight(int index) {
//     _lights[index] = !_lights[index];
//     notifyListeners();
//   }

//   void toggleStopwatch() {
//     _timerRunning = !_timerRunning;
//     if (_timerRunning) {
//       _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (t) {
//         _seconds++;
//         notifyListeners();
//       });
//     } else {
//       _stopwatchTimer?.cancel();
//     }
//     notifyListeners();
//   }

//   void resetStopwatch() {
//     _seconds = 0;
//     _timerRunning = false;
//     _stopwatchTimer?.cancel();
//     notifyListeners();
//   }
// }

// // --- MAIN DASHBOARD ---
// class MedicalDashboard extends StatelessWidget {
//   const MedicalDashboard({super.key});

//   final Color medicalTeal = const Color(0xFF00796B);
//   final Color darkText = const Color.fromARGB(255, 228, 234, 236);

//   ScreenSize _getScreenSize(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     if (width < 600) return ScreenSize.mobile;
//     if (width < 1200) return ScreenSize.tablet;
//     return ScreenSize.desktop;
//   }

//   @override
//   Widget build(BuildContext context) {
//     var pro = context.watch<ORSystemProvider>();

//     if (pro.viewMode == ORViewMode.orMode) {
//       return ORModeScreen();
//     }

//     return Scaffold(
//       body: Stack(
//         children: [
//           const BackgroundAnimation(),
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.all(20.0),
//               child: Column(
//                 children: [
//                   _buildORModeButton(context, pro),
//                   const SizedBox(height: 10),
//                   Expanded(
//                     flex: 5,
//                     child: Row(
//                       children: [
//                         _buildStaticPanel(
//                           child: Padding(
//                             padding: const EdgeInsets.all(20.0),
//                             child: CustomPaint(
//                               painter: ProfessionalClockPainter(pro.now),
//                               child: Container(),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 15),
//                         _buildFlippingTimerPanel(pro),
//                         const SizedBox(width: 15),
//                         _buildRightSidebar(pro),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 15),
//                   Expanded(
//                     flex: 3,
//                     child: Row(
//                       children: [
//                         _buildControlCard(
//                           "LIGHTING",
//                           Icons.wb_sunny_outlined,
//                           pro.lights.where((l) => l).length.toString(),
//                           onTap: () => _showLightControl(context, pro),
//                         ),
//                         _buildTempCard(pro),
//                         _buildHumidityCard(pro),
//                         _buildControlCard(
//                           "MUSIC",
//                           pro.isMusicPlaying
//                               ? Icons.music_note
//                               : Icons.music_off,
//                           pro.isMusicPlaying ? "ON" : "OFF",
//                           onTap: pro.toggleMusicFlip,
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 15),
//                   _buildFooter(context, pro),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildORModeButton(BuildContext context, ORSystemProvider pro) {
//     return Align(
//       alignment: Alignment.topRight,
//       child: GestureDetector(
//         onTap: () {
//           pro.setViewMode(ORViewMode.orMode);
//         },
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.2),
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(color: Colors.white, width: 2),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.3),
//                 blurRadius: 10,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Icon(Icons.medical_services, color: Colors.white, size: 24),
//               const SizedBox(width: 8),
//               Text(
//                 "OR MODE",
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                   letterSpacing: 1.2,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildRightSidebar(ORSystemProvider pro) {
//     return Expanded(
//       flex: 1,
//       child: MedicalFlipCard(
//         isFlipped: pro.showRightPanelFlip || pro.showMGPSFlip,
//         front: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             _buildCircleSetting(
//               Icons.air,
//               "HEPA",
//               true,
//               null,
//               color: Colors.green,
//             ),
//             const SizedBox(height: 25),
//             _buildCircleSetting(
//               Icons.settings,
//               "CONFIG",
//               true,
//               pro.toggleRightPanelFlip,
//             ),
//             const SizedBox(height: 25),
//             _buildCircleSetting(
//               Icons.gas_meter_outlined,
//               "MGPS",
//               true,
//               pro.toggleMGPSFlip,
//               color: Colors.orange,
//             ),
//           ],
//         ),
//         back: pro.showMGPSFlip ? _buildMGPSBack(pro) : _buildConfigBack(pro),
//       ),
//     );
//   }

//   Widget _buildConfigBack(ORSystemProvider pro) {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         const Text(
//           "SYSTEM CONFIG",
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//             color: Colors.white,
//           ),
//         ),
//         const SizedBox(height: 20),
//         _buildCircleSetting(
//           Icons.language,
//           "ENG",
//           true,
//           null,
//           color: Colors.blue,
//         ),
//         const SizedBox(height: 20),
//         TextButton(
//           onPressed: pro.toggleRightPanelFlip,
//           child: const Text(
//             "BACK",
//             style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildMGPSBack(ORSystemProvider pro) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 10.0),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Text(
//             "MGPS STATUS",
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               fontSize: 10,
//               color: Colors.orange,
//             ),
//           ),
//           const Divider(),
//           _gasStatusRow("Oxygen", Colors.green),
//           _gasStatusRow("Nitrogen", Colors.blue),
//           _gasStatusRow("Vacuum", Colors.yellow[700]!),
//           _gasStatusRow("Nitrous Oxide", Colors.blue[900]!),
//           const Spacer(),
//           TextButton(
//             onPressed: pro.toggleMGPSFlip,
//             child: const Text(
//               "CLOSE",
//               style: TextStyle(
//                 color: Colors.red,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 10,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _gasStatusRow(String name, Color color) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
//       child: Row(
//         children: [
//           Container(
//             width: 8,
//             height: 8,
//             decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               name,
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.white,
//               ),
//             ),
//           ),
//           const Icon(Icons.check_circle, color: Colors.green, size: 12),
//         ],
//       ),
//     );
//   }

//   Widget _buildTempCard(ORSystemProvider pro) {
//     return Expanded(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 6),
//         child: MedicalFlipCard(
//           isFlipped: pro.showTempSettings,
//           front: _buildCardContent(
//             "TEMP",
//             Icons.thermostat,
//             "${pro.temp.toStringAsFixed(1)}°C",
//             pro.toggleTempFlip,
//           ),
//           back: _buildAdjuster(
//             "SET TEMP",
//             pro.temp,
//             (v) => pro.adjustTemp(v),
//             pro.toggleTempFlip,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildHumidityCard(ORSystemProvider pro) {
//     return Expanded(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 6),
//         child: MedicalFlipCard(
//           isFlipped: pro.showHumiditySettings,
//           front: _buildCardContent(
//             "HUMIDITY",
//             Icons.water_drop_outlined,
//             "${pro.rh.toInt()}%",
//             pro.toggleHumidityFlip,
//           ),
//           back: _buildAdjuster(
//             "SET RH %",
//             pro.rh,
//             (v) => pro.adjustHumidity(v),
//             pro.toggleHumidityFlip,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildFooter(BuildContext context, ORSystemProvider pro) {
//     final screenSize = _getScreenSize(context);
//     return Row(
//       children: [
//         GestureDetector(
//           onTap: pro.toggleSystem,
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 300),
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: pro.isSystemOn
//                   ? Colors.green.withOpacity(0.1)
//                   : Colors.red.withOpacity(0.1),
//               border: Border.all(
//                 color: pro.isSystemOn ? Colors.green : Colors.red,
//                 width: 3,
//               ),
//             ),
//             child: Icon(
//               Icons.power_settings_new,
//               color: pro.isSystemOn ? Colors.green : Colors.red,
//               size: 32,
//             ),
//           ),
//         ),
//         const Spacer(),
//         Stack(
//           alignment: Alignment.center,
//           children: [
//             Center(
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(20.0),
//                 child: BackdropFilter(
//                   filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
//                   child: Container(
//                     height: screenSize == ScreenSize.tablet ? 100 : 120,
//                     width: screenSize == ScreenSize.tablet ? 200 : 270,
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.3),
//                       border: Border.all(
//                         color: Colors.white.withOpacity(0.2),
//                         width: 1.0,
//                       ),
//                     ),
//                     child: SizedBox(),
//                   ),
//                 ),
//               ),
//             ),
//             Center(
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(20.0),
//                 child: BackdropFilter(
//                   filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
//                   child: Container(
//                     height: screenSize == ScreenSize.tablet ? 80 : 100,
//                     width: screenSize == ScreenSize.tablet ? 180 : 250,
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.3),
//                       border: Border.all(
//                         color: Colors.white.withOpacity(0.2),
//                         width: 1.0,
//                       ),
//                     ),
//                     child: Center(
//                       child: Image.asset(
//                         'assets/app_logo-removebg-preview.png',
//                         height: screenSize == ScreenSize.tablet ? 80 : 100,
//                         width: screenSize == ScreenSize.tablet ? 240 : 300,
//                         fit: BoxFit.contain,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildStaticPanel({required Widget child, int flex = 1}) {
//     return Expanded(
//       flex: flex,
//       child: Container(
//         decoration: BoxDecoration(
//           color: Color.fromARGB(3, 18, 10, 45),
//           borderRadius: BorderRadius.circular(24),
//           boxShadow: [
//             BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20),
//           ],
//         ),
//         child: child,
//       ),
//     );
//   }

//   Widget _buildCardContent(
//     String title,
//     IconData icon,
//     String value,
//     VoidCallback onTap,
//   ) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(24),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontWeight: FontWeight.w900,
//               color: darkText.withOpacity(0.5),
//               fontSize: 12,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Icon(icon, color: medicalTeal, size: 36),
//           const SizedBox(height: 8),
//           Text(
//             value,
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: darkText,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildAdjuster(
//     String title,
//     double val,
//     Function(double) onAdjust,
//     VoidCallback close,
//   ) {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Text(
//           title,
//           style: const TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 14,
//             color: Colors.white,
//           ),
//         ),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             IconButton(
//               icon: const Icon(
//                 Icons.remove_circle_outline,
//                 color: Colors.white,
//               ),
//               onPressed: () => onAdjust(-0.5),
//             ),
//             Text(
//               val.toStringAsFixed(1),
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: medicalTeal,
//               ),
//             ),
//             IconButton(
//               icon: const Icon(Icons.add_circle_outline, color: Colors.white),
//               onPressed: () => onAdjust(0.5),
//             ),
//           ],
//         ),
//         TextButton(
//           onPressed: close,
//           child: const Text(
//             "DONE",
//             style: TextStyle(fontSize: 10, color: Colors.white),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildControlCard(
//     String title,
//     IconData icon,
//     String value, {
//     VoidCallback? onTap,
//   }) {
//     return Expanded(
//       child: Container(
//         margin: const EdgeInsets.symmetric(horizontal: 6),
//         decoration: BoxDecoration(
//           color: Colors.white.withOpacity(0.13),
//           borderRadius: BorderRadius.circular(24),
//           border: Border.all(color: Colors.white.withOpacity(0.8), width: 2.0),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.1),
//               blurRadius: 15,
//               offset: const Offset(0, 5),
//             ),
//           ],
//         ),
//         child: _buildCardContent(title, icon, value, onTap ?? () {}),
//       ),
//     );
//   }

//   Widget _buildFlippingTimerPanel(ORSystemProvider pro) {
//     return Expanded(
//       flex: 2,
//       child: MedicalFlipCard(
//         isFlipped: pro.showMusic,
//         front: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               "OR CONTROL PANEL",
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.w900,
//                 color: darkText,
//               ),
//             ),
//             Text(
//               pro.formattedFullDate,
//               style: TextStyle(fontSize: 12, color: darkText.withOpacity(0.6)),
//             ),
//             const Divider(height: 30, indent: 60, endIndent: 60),
//             Text(
//               pro.stopwatchDisplay,
//               style: TextStyle(
//                 fontSize: 60,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.white,
//               ),
//             ),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 _buildStopwatchBtn(
//                   icon: Icons.refresh,
//                   label: "RESET",
//                   onTap: pro.resetStopwatch,
//                 ),
//                 const SizedBox(width: 30),
//                 _buildStopwatchBtn(
//                   icon: pro.timerRunning ? Icons.pause : Icons.play_arrow,
//                   label: pro.timerRunning ? "PAUSE" : "START",
//                   onTap: pro.toggleStopwatch,
//                   primary: true,
//                 ),
//               ],
//             ),
//           ],
//         ),
//         back: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.library_music, color: medicalTeal, size: 30),
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Text(
//                 pro.currentTrack,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w900,
//                   color: darkText,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.skip_previous, color: medicalTeal),
//                   onPressed: pro.prevTrack,
//                 ),
//                 CircleAvatar(
//                   backgroundColor: medicalTeal,
//                   child: IconButton(
//                     icon: Icon(
//                       pro.isMusicPlaying ? Icons.pause : Icons.play_arrow,
//                       color: Colors.white,
//                     ),
//                     onPressed: pro.togglePlayPause,
//                   ),
//                 ),
//                 IconButton(
//                   icon: Icon(Icons.skip_next, color: medicalTeal),
//                   onPressed: pro.nextTrack,
//                 ),
//               ],
//             ),
//             TextButton(
//               onPressed: pro.toggleMusicFlip,
//               child: const Text(
//                 "CLOSE PLAYER",
//                 style: TextStyle(color: Colors.white),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStopwatchBtn({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//     bool primary = false,
//   }) {
//     return Column(
//       children: [
//         GestureDetector(
//           onTap: onTap,
//           child: CircleAvatar(
//             radius: 22,
//             backgroundColor: primary ? medicalTeal : Colors.teal,
//             child: Icon(
//               icon,
//               color: primary ? Colors.white : medicalTeal,
//               size: 20,
//             ),
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           label,
//           style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
//         ),
//       ],
//     );
//   }

//   Widget _buildCircleSetting(
//     IconData icon,
//     String label,
//     bool isOn,
//     VoidCallback? onTap, {
//     Color? color,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: Colors.white,
//               border: Border.all(
//                 color: isOn ? (color ?? medicalTeal) : Colors.black12,
//                 width: 2,
//               ),
//             ),
//             child: Icon(
//               icon,
//               color: isOn ? (color ?? medicalTeal) : Colors.black26,
//               size: 24,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             label,
//             style: const TextStyle(
//               fontSize: 9,
//               fontWeight: FontWeight.bold,
//               color: Colors.white,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showLightControl(BuildContext context, ORSystemProvider pro) {
//     showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) => AlertDialog(
//           title: const Text("LIGHTING CONTROL"),
//           content: Wrap(
//             spacing: 10,
//             children: List.generate(
//               4,
//               (i) => ChoiceChip(
//                 label: Text("ZONE ${i + 1}"),
//                 selected: pro.lights[i],
//                 onSelected: (val) {
//                   pro.toggleLight(i);
//                   setState(() {});
//                 },
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text("DONE"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // --- OR MODE SCREEN ---
// class ORModeScreen extends StatelessWidget {
//   ORModeScreen({super.key});

//   final Color medicalTeal = const Color(0xFF00796B);

//   // Demo patient data
//   final List<Patient> _demoPatients = [
//     Patient(
//       id: 'P001',
//       name: 'Rajesh Kumar',
//       age: 45,
//       gender: 'Male',
//       bloodGroup: 'B+',
//       admissionDate: '2024-01-15',
//       diagnosis: 'Coronary Artery Disease',
//       doctor: 'Dr. Sharma',
//       roomNumber: 'ICU-101',
//       status: 'Critical',
//       vitals: {
//         'BP': '150/95',
//         'HR': '110',
//         'Temp': '38.2°C',
//         'SpO2': '92%',
//         'RR': '24',
//       },
//       medications: [
//         'Aspirin 75mg',
//         'Atorvastatin 40mg',
//         'Metoprolol 50mg',
//         'Clopidogrel 75mg',
//       ],
//       labResults: [
//         'ECG: ST elevation in anterior leads',
//         'Troponin I: 5.2 ng/mL',
//         'CK-MB: 45 U/L',
//         'HbA1c: 7.2%',
//       ],
//       imagingReports: [
//         'Echocardiogram: EF 40%, anterior wall hypokinesia',
//         'Chest X-ray: Cardiomegaly, pulmonary congestion',
//       ],
//     ),
//     Patient(
//       id: 'P002',
//       name: 'Priya Sharma',
//       age: 32,
//       gender: 'Female',
//       bloodGroup: 'O+',
//       admissionDate: '2024-01-16',
//       diagnosis: 'Appendicitis',
//       doctor: 'Dr. Gupta',
//       roomNumber: 'WARD-205',
//       status: 'Stable',
//       vitals: {
//         'BP': '120/80',
//         'HR': '85',
//         'Temp': '37.8°C',
//         'SpO2': '98%',
//         'RR': '16',
//       },
//       medications: [
//         'Ceftriaxone 1g IV',
//         'Metronidazole 500mg',
//         'Paracetamol 650mg',
//         'Tramadol 50mg',
//       ],
//       labResults: [
//         'WBC: 15,000/mm³',
//         'CRP: 45 mg/L',
//         'Ultrasound: Enlarged appendix, 12mm diameter',
//       ],
//       imagingReports: [
//         'CT Abdomen: Acute appendicitis with peri-appendiceal fat stranding',
//       ],
//     ),
//     Patient(
//       id: 'P003',
//       name: 'Amit Patel',
//       age: 58,
//       gender: 'Male',
//       bloodGroup: 'A+',
//       admissionDate: '2024-01-14',
//       diagnosis: 'Pneumonia',
//       doctor: 'Dr. Joshi',
//       roomNumber: 'WARD-312',
//       status: 'Serious',
//       vitals: {
//         'BP': '130/85',
//         'HR': '95',
//         'Temp': '39.1°C',
//         'SpO2': '89%',
//         'RR': '28',
//       },
//       medications: [
//         'Azithromycin 500mg',
//         'Amoxicillin-Clavulanate 1.2g',
//         'Oseltamivir 75mg',
//         'Salbutamol Inhaler',
//       ],
//       labResults: [
//         'CBC: WBC 18,000, Neutrophils 85%',
//         'CRP: 120 mg/L',
//         'Blood Culture: Streptococcus pneumoniae',
//         'ABG: pH 7.32, pO2 65, pCO2 45',
//       ],
//       imagingReports: [
//         'Chest X-ray: Consolidation in right lower lobe',
//         'CT Thorax: Multifocal pneumonia with pleural effusion',
//       ],
//     ),
//     Patient(
//       id: 'P004',
//       name: 'Meena Devi',
//       age: 67,
//       gender: 'Female',
//       bloodGroup: 'AB+',
//       admissionDate: '2024-01-13',
//       diagnosis: 'CVA (Stroke)',
//       doctor: 'Dr. Reddy',
//       roomNumber: 'ICU-102',
//       status: 'Critical',
//       vitals: {
//         'BP': '180/100',
//         'HR': '75',
//         'Temp': '36.8°C',
//         'SpO2': '96%',
//         'RR': '18',
//       },
//       medications: [
//         'Alteplase IV',
//         'Aspirin 325mg',
//         'Atorvastatin 80mg',
//         'Mannitol 20%',
//         'Pantoprazole 40mg',
//       ],
//       labResults: [
//         'CT Brain: Acute ischemic infarct in left MCA territory',
//         'INR: 1.1',
//         'Platelets: 250,000/mm³',
//         'Glucose: 180 mg/dL',
//       ],
//       imagingReports: [
//         'MRI Brain: Diffusion restriction in left basal ganglia',
//         'Carotid Doppler: 70% stenosis left internal carotid',
//       ],
//     ),
//     Patient(
//       id: 'P005',
//       name: 'Vikram Singh',
//       age: 28,
//       gender: 'Male',
//       bloodGroup: 'B-',
//       admissionDate: '2024-01-17',
//       diagnosis: 'Multiple Trauma',
//       doctor: 'Dr. Malhotra',
//       roomNumber: 'ER-001',
//       status: 'Critical',
//       vitals: {
//         'BP': '90/60',
//         'HR': '125',
//         'Temp': '35.5°C',
//         'SpO2': '88%',
//         'RR': '32',
//       },
//       medications: [
//         'Tranexamic Acid 1g',
//         'Morphine 5mg',
//         'Ceftriaxone 2g',
//         'Metronidazole 500mg',
//       ],
//       labResults: [
//         'Hb: 8.5 g/dL',
//         'INR: 1.8',
//         'Lactate: 4.5 mmol/L',
//         'Base Deficit: -8',
//       ],
//       imagingReports: [
//         'FAST Scan: Free fluid in abdomen',
//         'CT Trauma Series: Splenic laceration, rib fractures 5-8',
//         'X-ray Pelvis: Pubic rami fractures',
//       ],
//     ),
//     Patient(
//       id: 'P006',
//       name: 'Sangeeta Iyer',
//       age: 42,
//       gender: 'Female',
//       bloodGroup: 'O-',
//       admissionDate: '2024-01-12',
//       diagnosis: 'Cholecystitis',
//       doctor: 'Dr. Kapoor',
//       roomNumber: 'WARD-406',
//       status: 'Stable',
//       vitals: {
//         'BP': '125/82',
//         'HR': '88',
//         'Temp': '37.5°C',
//         'SpO2': '97%',
//         'RR': '18',
//       },
//       medications: [
//         'Piperacillin-Tazobactam 4.5g',
//         'Ketorolac 30mg',
//         'Hyoscine 20mg',
//         'Pantoprazole 40mg',
//       ],
//       labResults: [
//         'WBC: 14,000/mm³',
//         'Bilirubin: 2.5 mg/dL',
//         'ALP: 280 U/L',
//         'Amylase: 120 U/L',
//       ],
//       imagingReports: [
//         'Ultrasound Abdomen: Gallbladder wall thickening, stones present',
//         'MRCP: CBD diameter 8mm, no stones in CBD',
//       ],
//     ),
//     Patient(
//       id: 'P007',
//       name: 'Ramesh Nair',
//       age: 55,
//       gender: 'Male',
//       bloodGroup: 'A-',
//       admissionDate: '2024-01-11',
//       diagnosis: 'Diabetic Ketoacidosis',
//       doctor: 'Dr. Desai',
//       roomNumber: 'ICU-103',
//       status: 'Serious',
//       vitals: {
//         'BP': '100/70',
//         'HR': '110',
//         'Temp': '36.9°C',
//         'SpO2': '96%',
//         'RR': '30',
//       },
//       medications: [
//         'Insulin IV infusion',
//         'Normal Saline',
//         'Potassium Chloride',
//         'Sodium Bicarbonate',
//       ],
//       labResults: [
//         'Glucose: 550 mg/dL',
//         'pH: 7.18',
//         'Ketones: 4+',
//         'HCO3: 12 mmol/L',
//         'Anion Gap: 25',
//       ],
//       imagingReports: ['Chest X-ray: Clear', 'CT Brain: No acute findings'],
//     ),
//     Patient(
//       id: 'P008',
//       name: 'Lakshmi Rao',
//       age: 38,
//       gender: 'Female',
//       bloodGroup: 'B+',
//       admissionDate: '2024-01-10',
//       diagnosis: 'Ectopic Pregnancy',
//       doctor: 'Dr. Chatterjee',
//       roomNumber: 'OT-RECOVERY',
//       status: 'Stable',
//       vitals: {
//         'BP': '115/75',
//         'HR': '92',
//         'Temp': '37.2°C',
//         'SpO2': '99%',
//         'RR': '20',
//       },
//       medications: [
//         'Methotrexate 50mg/m²',
//         'Folic Acid 5mg',
//         'Ibuprofen 400mg',
//         'Ondansetron 4mg',
//       ],
//       labResults: [
//         'Beta-hCG: 4500 mIU/mL',
//         'Hb: 10.5 g/dL',
//         'Progesterone: 8 ng/mL',
//       ],
//       imagingReports: [
//         'TVS: Right adnexal mass, no intrauterine gestation',
//         'Doppler: Peritrophoblastic flow around ectopic',
//       ],
//     ),
//     Patient(
//       id: 'P009',
//       name: 'Arjun Mehra',
//       age: 50,
//       gender: 'Male',
//       bloodGroup: 'O+',
//       admissionDate: '2024-01-09',
//       diagnosis: 'Renal Colic',
//       doctor: 'Dr. Bose',
//       roomNumber: 'WARD-308',
//       status: 'Stable',
//       vitals: {
//         'BP': '140/90',
//         'HR': '78',
//         'Temp': '37.0°C',
//         'SpO2': '97%',
//         'RR': '16',
//       },
//       medications: [
//         'Diclofenac 75mg IM',
//         'Tamsulosin 0.4mg',
//         'Ciprofloxacin 500mg',
//         'Paracetamol 1g',
//       ],
//       labResults: [
//         'Urine RBC: 50-60/HPF',
//         'Urine Culture: E.coli 10⁵ CFU',
//         'Creatinine: 1.2 mg/dL',
//         'Uric Acid: 8.5 mg/dL',
//       ],
//       imagingReports: [
//         'KUB X-ray: 8mm opacity in right ureter',
//         'CT KUB: 8mm stone at right UVJ with mild hydronephrosis',
//       ],
//     ),
//     Patient(
//       id: 'P010',
//       name: 'Sunita Verma',
//       age: 29,
//       gender: 'Female',
//       bloodGroup: 'AB-',
//       admissionDate: '2024-01-08',
//       diagnosis: 'Dengue Fever',
//       doctor: 'Dr. Khanna',
//       roomNumber: 'WARD-214',
//       status: 'Serious',
//       vitals: {
//         'BP': '95/65',
//         'HR': '105',
//         'Temp': '39.5°C',
//         'SpO2': '94%',
//         'RR': '22',
//       },
//       medications: [
//         'Paracetamol 650mg',
//         'IV Fluids',
//         'Platelet transfusion',
//         'Pantoprazole 40mg',
//       ],
//       labResults: [
//         'Platelets: 45,000/mm³',
//         'NS1 Antigen: Positive',
//         'IgM Dengue: Positive',
//         'HCT: 48%',
//       ],
//       imagingReports: [
//         'Ultrasound Abdomen: Gallbladder wall edema, ascites',
//         'Chest X-ray: Bilateral pleural effusion',
//       ],
//     ),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     var pro = context.watch<ORSystemProvider>();

//     return Scaffold(
//       body: Stack(
//         children: [
//           const BackgroundAnimation(),
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.all(20.0),
//               child: Column(
//                 children: [
//                   // Back to Dashboard Button
//                   Row(
//                     children: [
//                       GestureDetector(
//                         onTap: () {
//                           pro.setViewMode(ORViewMode.dashboard);
//                         },
//                         child: Container(
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.2),
//                             borderRadius: BorderRadius.circular(50),
//                             border: Border.all(color: Colors.white, width: 2),
//                           ),
//                           child: const Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(Icons.arrow_back, color: Colors.white),
//                               SizedBox(width: 8),
//                               Text(
//                                 "BACK TO DASHBOARD",
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       const Spacer(),
//                       Text(
//                         "OR MODE",
//                         style: TextStyle(
//                           fontSize: 24,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.white,
//                           letterSpacing: 2,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 30),

//                   // Grid View
//                   Expanded(
//                     child: GridView.count(
//                       crossAxisCount: 2,
//                       crossAxisSpacing: 20,
//                       mainAxisSpacing: 20,
//                       childAspectRatio: 2.2,
//                       padding: const EdgeInsets.all(20),
//                       children: [
//                         _buildGridItem(
//                           context,
//                           "OR SCREEN",
//                           Icons.desktop_windows,
//                           Colors.blue,
//                           () => _showFeatureDetails(
//                             context,
//                             "OR Screen",
//                             "Real-time surgical monitoring with multiple camera feeds and patient vitals overlay.",
//                           ),
//                         ),
//                         _buildGridItem(
//                           context,
//                           "PI",
//                           Icons.analytics,
//                           Colors.green,
//                           () => _navigateToPatientInfo(context),
//                         ),
//                         _buildGridItem(
//                           context,
//                           "CLEAN",
//                           Icons.cleaning_services,
//                           Colors.purple,
//                           () => Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => CleanControlApp(),
//                             ),
//                           ),
//                         ),
//                         _buildGridItem(
//                           context,
//                           "DICOM",
//                           Icons.medical_services,
//                           Colors.orange,
//                           () => _showFeatureDetails(
//                             context,
//                             "DICOM Viewer",
//                             "Medical imaging viewer with support for CT, MRI, X-Ray, and ultrasound in DICOM format.",
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildGridItem(
//     BuildContext context,
//     String title,
//     IconData icon,
//     Color color,
//     VoidCallback onTap,
//   ) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white.withOpacity(0.15),
//           borderRadius: BorderRadius.circular(24),
//           border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
//           boxShadow: [
//             BoxShadow(
//               color: color.withOpacity(0.3),
//               blurRadius: 20,
//               offset: const Offset(0, 10),
//             ),
//           ],
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: color.withOpacity(0.2),
//                 border: Border.all(color: color, width: 3),
//               ),
//               child: Icon(icon, size: 40, color: Colors.white),
//             ),
//             const SizedBox(height: 15),
//             Text(
//               title,
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.white,
//                 letterSpacing: 1.5,
//               ),
//             ),
//             const SizedBox(height: 5),
//             Text(
//               "TAP TO VIEW",
//               style: TextStyle(
//                 fontSize: 10,
//                 color: Colors.white.withOpacity(0.7),
//                 letterSpacing: 1.2,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _navigateToPatientInfo(BuildContext context) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => PatientInformationScreen(patients: _demoPatients),
//       ),
//     );
//   }

//   void _showFeatureDetails(
//     BuildContext context,
//     String title,
//     String description,
//   ) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.white.withOpacity(0.95),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
//         title: Text(
//           title,
//           style: TextStyle(
//             color: medicalTeal,
//             fontWeight: FontWeight.bold,
//             fontSize: 24,
//           ),
//         ),
//         content: Text(
//           description,
//           style: const TextStyle(fontSize: 16, height: 1.5),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text(
//               "CLOSE",
//               style: TextStyle(color: medicalTeal, fontWeight: FontWeight.bold),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // --- PATIENT INFORMATION SCREEN ---
// class PatientInformationScreen extends StatefulWidget {
//   final List<Patient> patients;

//   const PatientInformationScreen({super.key, required this.patients});

//   @override
//   State<PatientInformationScreen> createState() =>
//       _PatientInformationScreenState();
// }

// class _PatientInformationScreenState extends State<PatientInformationScreen> {
//   late List<Patient> _filteredPatients;
//   String _searchQuery = '';
//   String _selectedStatus = 'All';
//   String _selectedDepartment = 'All';

//   @override
//   void initState() {
//     super.initState();
//     _filteredPatients = widget.patients;
//   }

//   void _filterPatients() {
//     List<Patient> filtered = widget.patients;

//     if (_searchQuery.isNotEmpty) {
//       filtered = filtered
//           .where(
//             (patient) =>
//                 patient.name.toLowerCase().contains(
//                   _searchQuery.toLowerCase(),
//                 ) ||
//                 patient.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
//                 patient.diagnosis.toLowerCase().contains(
//                   _searchQuery.toLowerCase(),
//                 ) ||
//                 patient.doctor.toLowerCase().contains(
//                   _searchQuery.toLowerCase(),
//                 ),
//           )
//           .toList();
//     }

//     if (_selectedStatus != 'All') {
//       filtered = filtered
//           .where(
//             (patient) =>
//                 patient.status.toLowerCase() == _selectedStatus.toLowerCase(),
//           )
//           .toList();
//     }

//     if (_selectedDepartment != 'All') {
//       filtered = filtered.where((patient) {
//         if (patient.roomNumber.contains('ICU'))
//           return _selectedDepartment == 'ICU';
//         if (patient.roomNumber.contains('WARD'))
//           return _selectedDepartment == 'Ward';
//         if (patient.roomNumber.contains('ER'))
//           return _selectedDepartment == 'ER';
//         return _selectedDepartment == 'Other';
//       }).toList();
//     }

//     setState(() {
//       _filteredPatients = filtered;
//     });
//   }

//   Widget _buildPatientCard(Patient patient) {
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: InkWell(
//         onTap: () => _showPatientDetails(patient),
//         borderRadius: BorderRadius.circular(16),
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         patient.name,
//                         style: const TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.blueGrey,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         'ID: ${patient.id} | Age: ${patient.age} | ${patient.gender}',
//                         style: const TextStyle(
//                           fontSize: 14,
//                           color: Colors.grey,
//                         ),
//                       ),
//                     ],
//                   ),
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 6,
//                     ),
//                     decoration: BoxDecoration(
//                       color: patient.statusColor.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(20),
//                       border: Border.all(color: patient.statusColor, width: 1),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(
//                           patient.statusIcon,
//                           color: patient.statusColor,
//                           size: 16,
//                         ),
//                         const SizedBox(width: 6),
//                         Text(
//                           patient.status.toUpperCase(),
//                           style: TextStyle(
//                             fontSize: 12,
//                             fontWeight: FontWeight.bold,
//                             color: patient.statusColor,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               Divider(color: Colors.grey.shade300),
//               const SizedBox(height: 12),
//               Row(
//                 children: [
//                   _buildInfoItem(Icons.bloodtype, patient.bloodGroup),
//                   const SizedBox(width: 16),
//                   _buildInfoItem(Icons.local_hospital, patient.diagnosis),
//                   const SizedBox(width: 16),
//                   _buildInfoItem(Icons.person, patient.doctor),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               Row(
//                 children: [
//                   _buildInfoItem(Icons.room, patient.roomNumber),
//                   const SizedBox(width: 16),
//                   _buildInfoItem(Icons.calendar_today, patient.admissionDate),
//                 ],
//               ),
//               if (patient.vitals != null) ...[
//                 const SizedBox(height: 12),
//                 Divider(color: Colors.grey.shade300),
//                 const SizedBox(height: 8),
//                 Text(
//                   'Vitals',
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.blueGrey.shade700,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Wrap(
//                   spacing: 12,
//                   runSpacing: 8,
//                   children: patient.vitals!.entries.map((entry) {
//                     return Chip(
//                       label: Text('${entry.key}: ${entry.value}'),
//                       backgroundColor: Colors.blue.shade50,
//                       labelStyle: const TextStyle(fontSize: 12),
//                     );
//                   }).toList(),
//                 ),
//               ],
//               const SizedBox(height: 12),
//               Align(
//                 alignment: Alignment.centerRight,
//                 child: Text(
//                   'Tap for full details →',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: Colors.blue.shade600,
//                     fontStyle: FontStyle.italic,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildInfoItem(IconData icon, String text) {
//     return Expanded(
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 16, color: Colors.blueGrey.shade600),
//           const SizedBox(width: 6),
//           Expanded(
//             child: Text(
//               text,
//               style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showPatientDetails(Patient patient) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => PatientDetailBottomSheet(patient: patient),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Patient Information'),
//         backgroundColor: const Color(0xFF00796B),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: () {
//               setState(() {
//                 _searchQuery = '';
//                 _selectedStatus = 'All';
//                 _selectedDepartment = 'All';
//                 _filteredPatients = widget.patients;
//               });
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Search and Filter Bar
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               children: [
//                 TextField(
//                   decoration: InputDecoration(
//                     hintText: 'Search patients by name, ID, diagnosis...',
//                     prefixIcon: const Icon(Icons.search),
//                     filled: true,
//                     fillColor: Colors.grey.shade50,
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: BorderSide.none,
//                     ),
//                     contentPadding: const EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 14,
//                     ),
//                   ),
//                   onChanged: (value) {
//                     setState(() {
//                       _searchQuery = value;
//                     });
//                     _filterPatients();
//                   },
//                 ),
//                 const SizedBox(height: 12),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: DropdownButtonFormField<String>(
//                         value: _selectedStatus,
//                         decoration: InputDecoration(
//                           labelText: 'Status',
//                           filled: true,
//                           fillColor: Colors.grey.shade50,
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide.none,
//                           ),
//                           contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 12,
//                             vertical: 8,
//                           ),
//                         ),
//                         items:
//                             [
//                               'All',
//                               'Critical',
//                               'Serious',
//                               'Stable',
//                               'Discharged',
//                             ].map((String value) {
//                               return DropdownMenuItem<String>(
//                                 value: value,
//                                 child: Text(value),
//                               );
//                             }).toList(),
//                         onChanged: (value) {
//                           setState(() {
//                             _selectedStatus = value!;
//                           });
//                           _filterPatients();
//                         },
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: DropdownButtonFormField<String>(
//                         value: _selectedDepartment,
//                         decoration: InputDecoration(
//                           labelText: 'Department',
//                           filled: true,
//                           fillColor: Colors.grey.shade50,
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide.none,
//                           ),
//                           contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 12,
//                             vertical: 8,
//                           ),
//                         ),
//                         items: ['All', 'ICU', 'Ward', 'ER', 'Other'].map((
//                           String value,
//                         ) {
//                           return DropdownMenuItem<String>(
//                             value: value,
//                             child: Text(value),
//                           );
//                         }).toList(),
//                         onChanged: (value) {
//                           setState(() {
//                             _selectedDepartment = value!;
//                           });
//                           _filterPatients();
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),

//           // Statistics
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             child: Row(
//               children: [
//                 _buildStatCard(
//                   'Total',
//                   widget.patients.length.toString(),
//                   Icons.group,
//                   Colors.blue,
//                 ),
//                 const SizedBox(width: 8),
//                 _buildStatCard(
//                   'Critical',
//                   widget.patients
//                       .where((p) => p.status == 'Critical')
//                       .length
//                       .toString(),
//                   Icons.warning,
//                   Colors.red,
//                 ),
//                 const SizedBox(width: 8),
//                 _buildStatCard(
//                   'Stable',
//                   widget.patients
//                       .where((p) => p.status == 'Stable')
//                       .length
//                       .toString(),
//                   Icons.check_circle,
//                   Colors.green,
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 12),

//           // Patients List
//           Expanded(
//             child: _filteredPatients.isEmpty
//                 ? Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Icon(
//                           Icons.search_off,
//                           size: 64,
//                           color: Colors.grey,
//                         ),
//                         const SizedBox(height: 16),
//                         Text(
//                           'No patients found',
//                           style: TextStyle(
//                             fontSize: 18,
//                             color: Colors.grey.shade600,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           'Try adjusting your search or filters',
//                           style: TextStyle(
//                             fontSize: 14,
//                             color: Colors.grey.shade500,
//                           ),
//                         ),
//                       ],
//                     ),
//                   )
//                 : ListView.builder(
//                     itemCount: _filteredPatients.length,
//                     itemBuilder: (context, index) {
//                       return _buildPatientCard(_filteredPatients[index]);
//                     },
//                   ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatCard(
//     String title,
//     String value,
//     IconData icon,
//     Color color,
//   ) {
//     return Expanded(
//       child: Card(
//         elevation: 2,
//         child: Padding(
//           padding: const EdgeInsets.all(12),
//           child: Column(
//             children: [
//               Icon(icon, color: color, size: 24),
//               const SizedBox(height: 8),
//               Text(
//                 value,
//                 style: const TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 title,
//                 style: const TextStyle(fontSize: 12, color: Colors.grey),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // --- PATIENT DETAIL BOTTOM SHEET ---
// class PatientDetailBottomSheet extends StatelessWidget {
//   final Patient patient;

//   const PatientDetailBottomSheet({super.key, required this.patient});

//   @override
//   Widget build(BuildContext context) {
//     return DraggableScrollableSheet(
//       initialChildSize: 0.9,
//       minChildSize: 0.5,
//       maxChildSize: 0.95,
//       builder: (context, scrollController) {
//         return Container(
//           decoration: const BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.only(
//               topLeft: Radius.circular(24),
//               topRight: Radius.circular(24),
//             ),
//           ),
//           child: Column(
//             children: [
//               // Draggable Handle
//               Container(
//                 width: 40,
//                 height: 5,
//                 margin: const EdgeInsets.only(top: 12, bottom: 8),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade400,
//                   borderRadius: BorderRadius.circular(2.5),
//                 ),
//               ),

//               // Header
//               Padding(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 20,
//                   vertical: 12,
//                 ),
//                 child: Row(
//                   children: [
//                     CircleAvatar(
//                       backgroundColor: patient.statusColor.withOpacity(0.1),
//                       child: Icon(
//                         patient.statusIcon,
//                         color: patient.statusColor,
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             patient.name,
//                             style: const TextStyle(
//                               fontSize: 22,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.blueGrey,
//                             ),
//                           ),
//                           Text(
//                             '${patient.age}y • ${patient.gender} • ${patient.bloodGroup}',
//                             style: const TextStyle(
//                               fontSize: 14,
//                               color: Colors.grey,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 6,
//                       ),
//                       decoration: BoxDecoration(
//                         color: patient.statusColor.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(20),
//                         border: Border.all(
//                           color: patient.statusColor,
//                           width: 1,
//                         ),
//                       ),
//                       child: Text(
//                         patient.status.toUpperCase(),
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.bold,
//                           color: patient.statusColor,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               Divider(color: Colors.grey.shade300, height: 1),

//               // Content
//               Expanded(
//                 child: SingleChildScrollView(
//                   controller: scrollController,
//                   padding: const EdgeInsets.all(20),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Basic Info
//                       _buildSectionTitle('Patient Information'),
//                       const SizedBox(height: 12),
//                       _buildInfoRow('Patient ID', patient.id),
//                       _buildInfoRow('Admission Date', patient.admissionDate),
//                       _buildInfoRow('Room/Bed', patient.roomNumber),
//                       _buildInfoRow('Attending Doctor', patient.doctor),
//                       _buildInfoRow('Primary Diagnosis', patient.diagnosis),

//                       const SizedBox(height: 24),

//                       // Vitals
//                       if (patient.vitals != null) ...[
//                         _buildSectionTitle('Current Vitals'),
//                         const SizedBox(height: 12),
//                         GridView.count(
//                           crossAxisCount: 2,
//                           shrinkWrap: true,
//                           physics: const NeverScrollableScrollPhysics(),
//                           childAspectRatio: 3,
//                           crossAxisSpacing: 12,
//                           mainAxisSpacing: 12,
//                           children: patient.vitals!.entries.map((entry) {
//                             return _buildVitalCard(entry.key, entry.value);
//                           }).toList(),
//                         ),
//                         const SizedBox(height: 24),
//                       ],

//                       // Medications
//                       if (patient.medications != null &&
//                           patient.medications!.isNotEmpty) ...[
//                         _buildSectionTitle('Current Medications'),
//                         const SizedBox(height: 12),
//                         Column(
//                           children: patient.medications!.map((med) {
//                             return ListTile(
//                               leading: const Icon(Icons.medication, size: 20),
//                               title: Text(med),
//                               contentPadding: EdgeInsets.zero,
//                               visualDensity: const VisualDensity(vertical: -4),
//                             );
//                           }).toList(),
//                         ),
//                         const SizedBox(height: 24),
//                       ],

//                       // Lab Results
//                       if (patient.labResults != null &&
//                           patient.labResults!.isNotEmpty) ...[
//                         _buildSectionTitle('Laboratory Results'),
//                         const SizedBox(height: 12),
//                         Column(
//                           children: patient.labResults!.map((result) {
//                             return ListTile(
//                               leading: const Icon(Icons.science, size: 20),
//                               title: Text(result),
//                               contentPadding: EdgeInsets.zero,
//                               visualDensity: const VisualDensity(vertical: -4),
//                             );
//                           }).toList(),
//                         ),
//                         const SizedBox(height: 24),
//                       ],

//                       // Imaging Reports
//                       if (patient.imagingReports != null &&
//                           patient.imagingReports!.isNotEmpty) ...[
//                         _buildSectionTitle('Imaging Reports'),
//                         const SizedBox(height: 12),
//                         Column(
//                           children: patient.imagingReports!.map((report) {
//                             return ListTile(
//                               leading: const Icon(
//                                 Icons.photo_library,
//                                 size: 20,
//                               ),
//                               title: Text(report),
//                               contentPadding: EdgeInsets.zero,
//                               visualDensity: const VisualDensity(vertical: -4),
//                             );
//                           }).toList(),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildSectionTitle(String title) {
//     return Text(
//       title,
//       style: const TextStyle(
//         fontSize: 18,
//         fontWeight: FontWeight.bold,
//         color: Color(0xFF00796B),
//       ),
//     );
//   }

//   Widget _buildInfoRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 140,
//             child: Text(
//               label,
//               style: const TextStyle(
//                 fontWeight: FontWeight.w500,
//                 color: Colors.grey,
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               value,
//               style: const TextStyle(fontSize: 15, color: Colors.blueGrey),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildVitalCard(String title, String value) {
//     Color getVitalColor(String vital, String value) {
//       if (vital == 'BP') {
//         final parts = value.split('/');
//         if (parts.length == 2) {
//           final systolic = int.tryParse(parts[0]) ?? 0;
//           if (systolic > 140) return Colors.orange;
//           if (systolic < 90) return Colors.red;
//         }
//       } else if (vital == 'SpO2') {
//         final spO2 = int.tryParse(value.replaceAll('%', '')) ?? 0;
//         if (spO2 < 92) return Colors.red;
//         if (spO2 < 95) return Colors.orange;
//       } else if (vital == 'Temp') {
//         final temp = double.tryParse(value.replaceAll('°C', '')) ?? 0;
//         if (temp > 38) return Colors.orange;
//       }
//       return Colors.green;
//     }

//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: getVitalColor(title, value).withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: getVitalColor(title, value).withOpacity(0.3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.bold,
//               color: getVitalColor(title, value),
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             value,
//             style: const TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//               color: Colors.blueGrey,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // --- FLIP COMPONENT ---
// class MedicalFlipCard extends StatelessWidget {
//   final bool isFlipped;
//   final Widget front;
//   final Widget back;

//   const MedicalFlipCard({
//     super.key,
//     required this.isFlipped,
//     required this.front,
//     required this.back,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return TweenAnimationBuilder(
//       duration: const Duration(milliseconds: 600),
//       curve: Curves.easeInOut,
//       tween: Tween<double>(begin: 0, end: isFlipped ? 180 : 0),
//       builder: (context, double value, child) {
//         bool showFront = value < 90;
//         return Transform(
//           transform: Matrix4.identity()
//             ..setEntry(3, 2, 0.001)
//             ..rotateY(value * math.pi / 180),
//           alignment: Alignment.center,
//           child: Container(
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.13),
//               borderRadius: BorderRadius.circular(24),
//               border: Border.all(
//                 color: Colors.white.withOpacity(0.8),
//                 width: 2.0,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.1),
//                   blurRadius: 15,
//                   offset: const Offset(0, 5),
//                 ),
//               ],
//             ),
//             child: showFront
//                 ? front
//                 : Transform(
//                     alignment: Alignment.center,
//                     transform: Matrix4.identity()..rotateY(math.pi),
//                     child: back,
//                   ),
//           ),
//         );
//       },
//     );
//   }
// }

// // --- BACKGROUND ANIMATION ---
// class BackgroundAnimation extends StatefulWidget {
//   const BackgroundAnimation({super.key});
//   @override
//   State<BackgroundAnimation> createState() => _BackgroundAnimationState();
// }

// class _BackgroundAnimationState extends State<BackgroundAnimation>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 20),
//     )..repeat();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _controller,
//       builder: (context, child) {
//         return Stack(
//           children: [
//             // Background Image
//             Container(
//               width: double.infinity,
//               height: double.infinity,
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.centerLeft,
//                   end: Alignment.centerRight,
//                   colors: [
//                     Color.fromARGB(255, 44, 16, 90), // Soft Blue
//                     Color.fromARGB(255, 68, 49, 127), // Deep Purple/Violet
//                   ],
//                 ),
//                 // image: DecorationImage(
//                 //   image: AssetImage('assets/baground.png'),
//                 //   fit: BoxFit.cover,
//                 // ),
//               ),
//             ),

//             // Dark overlay for better readability
//             Container(
//               width: double.infinity,
//               height: double.infinity,
//               color: Colors.black.withOpacity(0.3),
//             ),

//             // Animated glow effects
//             _buildBlob(
//               size: 500,
//               xOffset: MediaQuery.of(context).size.width * 0.6,
//               yOffset: -100,
//               color: const Color(0xFF1E3A8A).withOpacity(0.3),
//               speedMult: 0.5,
//             ),
//             _buildBlob(
//               size: 600,
//               xOffset: -150,
//               yOffset: MediaQuery.of(context).size.height * 0.5,
//               color: const Color(0xFF0D9488).withOpacity(0.15),
//               speedMult: 0.3,
//             ),
//             _buildBlob(
//               size: 400,
//               xOffset: MediaQuery.of(context).size.width * 0.3,
//               yOffset: MediaQuery.of(context).size.height * 0.2,
//               color: const Color(0xFF3B82F6).withOpacity(0.1),
//               speedMult: 0.7,
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildBlob({
//     required double size,
//     required double xOffset,
//     required double yOffset,
//     required Color color,
//     double speedMult = 1.0,
//   }) {
//     final double animValue = _controller.value * 2 * math.pi * speedMult;

//     return Positioned(
//       left: xOffset + (math.sin(animValue) * 40),
//       top: yOffset + (math.cos(animValue) * 40),
//       child: Container(
//         width: size,
//         height: size,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           boxShadow: [
//             BoxShadow(color: color, blurRadius: 100, spreadRadius: 50),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // --- PROFESSIONAL CLOCK PAINTER ---
// class ProfessionalClockPainter extends CustomPainter {
//   final DateTime time;
//   ProfessionalClockPainter(this.time);
//   @override
//   void paint(Canvas canvas, Size size) {
//     final center = Offset(size.width / 2, size.height / 2);
//     final radius = size.width / 2.2;
//     final paint = Paint()..strokeCap = StrokeCap.round;
//     canvas.drawCircle(
//       center,
//       radius,
//       Paint()
//         ..color = Colors.white
//         ..style = PaintingStyle.fill,
//     );
//     canvas.drawCircle(
//       center,
//       radius,
//       Paint()
//         ..color = const Color(0xFF263238)
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 5,
//     );
//     for (var i = 0; i < 60; i++) {
//       double angle = i * 6 * math.pi / 180;
//       if (i % 5 == 0) {
//         canvas.drawLine(
//           _pos(center, angle, radius),
//           _pos(center, angle, radius - 12),
//           paint
//             ..strokeWidth = 3
//             ..color = const Color(0xFF263238),
//         );
//         final textPainter = TextPainter(
//           text: TextSpan(
//             text: '${i == 0 ? 12 : i ~/ 5}',
//             style: const TextStyle(
//               color: Color(0xFF263238),
//               fontSize: 16,
//               fontWeight: FontWeight.w900,
//             ),
//           ),
//           textDirection: ui.TextDirection.ltr,
//         )..layout();
//         Offset textPos = _pos(center, angle, radius - 32);
//         textPainter.paint(
//           canvas,
//           Offset(
//             textPos.dx - textPainter.width / 2,
//             textPos.dy - textPainter.height / 2,
//           ),
//         );
//       } else {
//         canvas.drawLine(
//           _pos(center, angle, radius),
//           _pos(center, angle, radius - 6),
//           paint
//             ..strokeWidth = 1.5
//             ..color = Colors.black12,
//         );
//       }
//     }
//     double h = (time.hour % 12 + time.minute / 60) * 30 * math.pi / 180;
//     double m = (time.minute + time.second / 60) * 6 * math.pi / 180;
//     double s = (time.second + time.millisecond / 1000) * 6 * math.pi / 180;
//     canvas.drawLine(
//       center,
//       _pos(center, h, radius * 0.5),
//       paint
//         ..strokeWidth = 7
//         ..color = const Color(0xFF263238),
//     );
//     canvas.drawLine(
//       center,
//       _pos(center, m, radius * 0.75),
//       paint
//         ..strokeWidth = 4
//         ..color = const Color(0xFF455A64),
//     );
//     canvas.drawLine(
//       center,
//       _pos(center, s, radius * 0.85),
//       paint
//         ..strokeWidth = 2
//         ..color = Colors.redAccent,
//     );
//     canvas.drawCircle(center, 6, Paint()..color = const Color(0xFF263238));
//   }

//   Offset _pos(Offset center, double angle, double len) => Offset(
//     center.dx + len * math.sin(angle),
//     center.dy - len * math.cos(angle),
//   );
//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }
