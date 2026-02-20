// // import 'dart:convert';
// // import 'package:flutter/material.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:surgeon_control_panel/patient%20info/dashboard_items/user/user_list.dart';

// // class HISApiService {
// //   final String baseUrl = "https://hapi.fhir.org/baseR4";

// //   /// Fetch patients from HIS (FHIR API)
// //   Future<List<Map<String, dynamic>>> fetchPatients() async {
// //     final url = Uri.parse("$baseUrl/Patient?_count=10");
// //     final response = await http.get(url);

// //     if (response.statusCode == 200) {
// //       final data = json.decode(response.body);

// //       // Extract patient entries
// //       List<Map<String, dynamic>> patients = [];
// //       if (data['entry'] != null) {
// //         for (var entry in data['entry']) {
// //           final resource = entry['resource'];
// //           patients.add({
// //             "id": resource['id'],
// //             "name": resource['name'] != null
// //                 ? resource['name'][0]['given']?.join(" ") ?? "Unknown"
// //                 : "Unknown",
// //             "gender": resource['gender'] ?? "N/A",
// //           });
// //         }
// //       }
// //       return patients;
// //     } else {
// //       throw Exception("Failed to load patients: ${response.statusCode}");
// //     }
// //   }
// // }

// // class PatientListScreen extends StatefulWidget {
// //   @override
// //   _PatientListScreenState createState() => _PatientListScreenState();
// // }

// // class _PatientListScreenState extends State<PatientListScreen> {
// //   final HISApiService apiService = HISApiService();
// //   late Future<List<Map<String, dynamic>>> patientsFuture;

// //   @override
// //   void initState() {
// //     super.initState();
// //     patientsFuture = apiService.fetchPatients();
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(title: const Text("Patient List")),
// //       body: FutureBuilder<List<Map<String, dynamic>>>(
// //         future: patientsFuture,
// //         builder: (context, snapshot) {
// //           if (snapshot.connectionState == ConnectionState.waiting) {
// //             return const Center(child: CircularProgressIndicator());
// //           } else if (snapshot.hasError) {
// //             return Center(child: Text("Error: ${snapshot.error}"));
// //           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
// //             return const Center(child: Text("No patients found"));
// //           }

// //           final patients = snapshot.data!;
// //           return ListView.builder(
// //             itemCount: patients.length,
// //             itemBuilder: (context, index) {
// //               final patient = patients[index];
// //               return Card(
// //                 child: ListTile(
// //                   title: Text(patient['name']),
// //                   subtitle: Text("Gender: ${patient['gender']}"),
// //                   trailing: TextButton(
// //                     onPressed: () {
// //                       Navigator.push(
// //                         context,
// //                         MaterialPageRoute(
// //                           builder: (context) => HospitalPortalApp(),
// //                         ),
// //                       );
// //                     },
// //                     child: Text("#${patient['id']}"),
// //                   ),
// //                 ),
// //               );
// //             },
// //           );
// //         },
// //       ),
// //     );
// //   }
// // }
// import 'dart:async';

// import 'package:flutter/material.dart';

// // --- Placeholder Screens ---
// // You can replace these with your actual screen widgets.
// class VideoScreen extends StatelessWidget {
//   const VideoScreen({Key? key}) : super(key: key);
//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       backgroundColor: Color(0xFF1E212A),
//       body: Center(
//         child: Text(
//           'Video Screen',
//           style: TextStyle(color: Colors.white, fontSize: 24),
//         ),
//       ),
//     );
//   }
// }

// class FolderScreen extends StatelessWidget {
//   const FolderScreen({Key? key}) : super(key: key);
//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       backgroundColor: Color(0xFF1E212A),
//       body: Center(
//         child: Text(
//           'Folder Screen',
//           style: TextStyle(color: Colors.white, fontSize: 24),
//         ),
//       ),
//     );
//   }
// }

// class ChartScreen extends StatelessWidget {
//   const ChartScreen({Key? key}) : super(key: key);
//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       backgroundColor: Color(0xFF1E212A),
//       body: Center(
//         child: Text(
//           'Chart Screen',
//           style: TextStyle(color: Colors.white, fontSize: 24),
//         ),
//       ),
//     );
//   }
// }

// class SettingsScreen extends StatelessWidget {
//   const SettingsScreen({Key? key}) : super(key: key);
//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       backgroundColor: Color(0xFF1E212A),
//       body: Center(
//         child: Text(
//           'Settings Screen',
//           style: TextStyle(color: Colors.white, fontSize: 24),
//         ),
//       ),
//     );
//   }
// }

// // Main screen that holds the dashboard UI and the bottom navigation
// class MainDashboardScreen extends StatefulWidget {
//   const MainDashboardScreen({Key? key}) : super(key: key);

//   @override
//   State<MainDashboardScreen> createState() => _MainDashboardScreenState();
// }

// class _MainDashboardScreenState extends State<MainDashboardScreen> {
//   int _selectedIndex = 0;
//   bool _isHeartRateCardSelected = false;
//   late Timer _timer;
//   int _seconds = 0;

//   // Color Palette
//   static const Color darkBg = Color(0xFF1E212A);
//   static const Color cardColor = Color(0xFF2B3039);
//   static const Color highlightCardColor = Color(0xFF383D4A);
//   static const Color textColor = Colors.white;
//   static const Color redColor = Color(0xFFFF5252);
//   static const Color blueColor = Color(0xFF53A1FF);
//   static const Color yellowColor = Color(0xFFFFCC00);
//   static const Color fadedTextColor = Colors.white54;

//   // List of screens for the bottom navigation
//   static final List<Widget> _screens = <Widget>[
//     const PatientDashboard(), // The main dashboard UI
//     const VideoScreen(),
//     const FolderScreen(),
//     const ChartScreen(),
//     const SettingsScreen(),
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (mounted) {
//         setState(() {
//           _seconds++;
//         });
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _timer.cancel();
//     super.dispose();
//   }

//   String _formatTime(int seconds) {
//     final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
//     final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
//     return '00:$minutes:$remainingSeconds';
//   }

//   // --- Main Build Method for the overall app structure ---
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: darkBg,
//       body: IndexedStack(
//         index: _selectedIndex,
//         children: [
//           _buildDashboardContent(), // The main dashboard layout
//           ..._screens.skip(1), // Add the other screens here
//         ],
//       ),
//       bottomNavigationBar: Container(
//         decoration: BoxDecoration(
//           color: cardColor,
//           borderRadius: BorderRadius.circular(16),
//         ),
//         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         padding: const EdgeInsets.symmetric(vertical: 8),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: [
//             _buildNavIcon(Icons.videocam_outlined, 0),
//             _buildNavIcon(Icons.folder_open, 1),
//             _buildNavIcon(Icons.monitor_heart_outlined, 2),
//             _buildNavIcon(Icons.show_chart, 3),
//             _buildNavIcon(Icons.settings_outlined, 4),
//           ],
//         ),
//       ),
//     );
//   }

//   // A method to build the main dashboard content
//   Widget _buildDashboardContent() {
//     return SafeArea(
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Top Bar
//             _buildTopBar(),
//             const SizedBox(height: 24),
//             // Patient Info Card
//             _buildPatientInfo(),
//             const SizedBox(height: 24),
//             // Vitals Cards
//             _buildVitals(),
//             const SizedBox(height: 24),
//             // Surgery Timer and Alerts
//             _buildTimerAndAlerts(),
//             const Spacer(),
//           ],
//         ),
//       ),
//     );
//   }

//   // ... (rest of the helper methods remain the same) ...

//   Widget _buildNavIcon(IconData icon, int index) {
//     final bool isSelected = _selectedIndex == index;
//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           _selectedIndex = index;
//         });
//       },
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, color: isSelected ? textColor : fadedTextColor, size: 32),
//           AnimatedContainer(
//             duration: const Duration(milliseconds: 300),
//             height: 4,
//             width: isSelected ? 32 : 0,
//             margin: const EdgeInsets.only(top: 4),
//             decoration: BoxDecoration(
//               color: textColor,
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTopBar() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         const Text(
//           'PATIENT INFORMATION',
//           style: TextStyle(
//             color: fadedTextColor,
//             fontSize: 12,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         Row(
//           children: [
//             Container(width: 16, height: 2, color: fadedTextColor),
//             const SizedBox(width: 4),
//             Container(width: 8, height: 2, color: fadedTextColor),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildPatientInfo() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: const [
//         Text(
//           'Michael Smith',
//           style: TextStyle(
//             color: textColor,
//             fontSize: 32,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         Text(
//           'Dr. Johnson',
//           style: TextStyle(color: fadedTextColor, fontSize: 16),
//         ),
//         SizedBox(height: 16),
//         Text(
//           'Laparoscopic\nCholecystectomy',
//           style: TextStyle(
//             color: textColor,
//             fontSize: 20,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildVitals() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         _buildVitalCard(
//           icon: Icons.favorite,
//           iconColor: redColor,
//           value: '75',
//           unit: 'BPM',
//           valueColor: redColor,
//           isSelectable: true,
//         ),
//         _buildVitalCard(
//           icon: Icons.insert_chart,
//           iconColor: textColor,
//           value: '120/80',
//           unit: 'mmHg',
//           valueColor: textColor,
//         ),
//         _buildVitalCard(
//           icon: Icons.check_circle,
//           iconColor: blueColor,
//           value: '99%',
//           unit: 'SpO2',
//           valueColor: blueColor,
//         ),
//       ],
//     );
//   }

//   Widget _buildTimerAndAlerts() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [_buildTimerCard(), _buildAlertCard()],
//     );
//   }

//   Widget _buildVitalCard({
//     required IconData icon,
//     required Color iconColor,
//     required String value,
//     required String unit,
//     required Color valueColor,
//     bool isSelectable = false,
//   }) {
//     Color currentCardColor = cardColor;
//     if (isSelectable && _isHeartRateCardSelected) {
//       currentCardColor = highlightCardColor;
//     }

//     return Expanded(
//       child: GestureDetector(
//         onTap: () {
//           if (isSelectable) {
//             setState(() {
//               _isHeartRateCardSelected = !_isHeartRateCardSelected;
//             });
//           }
//         },
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeInOut,
//           margin: const EdgeInsets.symmetric(horizontal: 4),
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: currentCardColor,
//             borderRadius: BorderRadius.circular(16),
//           ),
//           child: Column(
//             children: [
//               Icon(icon, color: iconColor, size: 28),
//               const SizedBox(height: 8),
//               Text(
//                 value,
//                 style: TextStyle(
//                   color: valueColor,
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 unit,
//                 style: const TextStyle(color: fadedTextColor, fontSize: 12),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTimerCard() {
//     final timeString = _formatTime(_seconds);
//     return Expanded(
//       child: Container(
//         margin: const EdgeInsets.symmetric(horizontal: 4),
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: cardColor,
//           borderRadius: BorderRadius.circular(16),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             AnimatedSwitcher(
//               duration: const Duration(milliseconds: 300),
//               transitionBuilder: (Widget child, Animation<double> animation) {
//                 return FadeTransition(opacity: animation, child: child);
//               },
//               child: Text(
//                 timeString,
//                 key: ValueKey<String>(timeString),
//                 style: const TextStyle(
//                   color: textColor,
//                   fontSize: 28,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 8),
//             const Text(
//               'SURGERY TIMER',
//               style: TextStyle(color: fadedTextColor, fontSize: 12),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAlertCard() {
//     return Expanded(
//       child: Container(
//         margin: const EdgeInsets.symmetric(horizontal: 4),
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: cardColor,
//           borderRadius: BorderRadius.circular(16),
//         ),
//         child: Row(
//           children: const [
//             Icon(Icons.warning, color: yellowColor, size: 36),
//             SizedBox(width: 8),
//             Text(
//               'MEDICAL\nALERTS',
//               style: TextStyle(
//                 color: textColor,
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // A new class for the main dashboard content
// class PatientDashboard extends StatelessWidget {
//   const PatientDashboard({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       // This is a placeholder. The actual content is in the parent widget.
//       // In a real app, this widget would contain the full dashboard UI.
//     );
//   }
// }
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(RelayControlApp());
}

class RelayControlApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Relay Control',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(
          0xFF1A1A2E,
        ), // Dark theme background
      ),
      home: RelayControlScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RelayControlScreen extends StatefulWidget {
  @override
  _RelayControlScreenState createState() => _RelayControlScreenState();
}

class _RelayControlScreenState extends State<RelayControlScreen> {
  final TextEditingController _ipController = TextEditingController();
  String _statusMessage = 'Enter ESP32 IP and connect';
  String _currentIp = '';
  bool _isConnected = false;
  String _currentMode = 'UP'; // Track current mode: UP or OFF

  // Function to control a relay
  Future<void> _controlRelay(int relayNumber) async {
    if (_currentIp.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter ESP32 IP address first';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Activating Relay ${relayNumber + 1}...';
    });

    try {
      // Correctly send relay numbers 1-10 to the ESP32.
      final response = await http
          .get(
            Uri.parse('http://$_currentIp/control?relay=${relayNumber + 1}'),
            headers: {'Connection': 'close'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = response.body;
        });

        // Clear status after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _statusMessage = 'Ready to control relays';
            });
          }
        });
      } else {
        setState(() {
          _statusMessage =
              'Error: Server returned status code ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  // Function to control the dial relay
  Future<void> _controlDialRelay() async {
    if (_currentIp.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter ESP32 IP address first';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Activating Dial Relay...';
    });

    try {
      final response = await http
          .get(
            Uri.parse('http://$_currentIp/dial'),
            headers: {'Connection': 'close'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = response.body;
        });

        // Clear status after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _statusMessage = 'Ready to control relays';
            });
          }
        });
      } else {
        setState(() {
          _statusMessage =
              'Error: Server returned status code ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  // Function to set UP mode
  Future<void> _setUpMode() async {
    if (_currentIp.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter ESP32 IP address first';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Setting UP mode...';
    });

    try {
      final response = await http
          .get(
            Uri.parse('http://$_currentIp/up'),
            headers: {'Connection': 'close'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = response.body;
          _currentMode = 'UP';
        });

        // Clear status after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _statusMessage = 'UP mode activated';
            });
          }
        });
      } else {
        setState(() {
          _statusMessage =
              'Error: Server returned status code ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  // Function to set OFF mode
  Future<void> _setOffMode() async {
    if (_currentIp.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter ESP32 IP address first';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Setting OFF mode...';
    });

    try {
      final response = await http
          .get(
            Uri.parse('http://$_currentIp/off'),
            headers: {'Connection': 'close'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = response.body;
          _currentMode = 'OFF';
        });

        // Clear status after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _statusMessage = 'OFF mode activated';
            });
          }
        });
      } else {
        setState(() {
          _statusMessage =
              'Error: Server returned status code ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  // Function to test connection
  Future<void> _testConnection() async {
    if (_ipController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter an IP address';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Connecting...';
      _currentIp = _ipController.text;
    });

    try {
      final response = await http
          .get(
            Uri.parse('http://$_currentIp/status'),
            headers: {'Connection': 'close'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Parse mode from response
        final responseText = response.body;
        if (responseText.contains('Mode:UP')) {
          _currentMode = 'UP';
        } else if (responseText.contains('Mode:OFF')) {
          _currentMode = 'OFF';
        }

        setState(() {
          _isConnected = true;
          _statusMessage =
              'Connected successfully! Current mode: $_currentMode';
        });
      } else {
        setState(() {
          _isConnected = false;
          _statusMessage =
              'Connection failed: Server returned status code ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage = 'Connection failed: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Blurred background layer
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1E1E2C),
                  Color(0xFF2D2D44),
                  Color(0xFF1E1E2C),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
          ),

          // Main scrollable content
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 40.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Main Title
                const Text(
                  'ESP32 Relay Control',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE0F7FA),
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black54,
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Connection Section
                _buildGlassmorphismCard(
                  child: Column(
                    children: [
                      // IP Address Input
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ipController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'ESP32 IP Address',
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                hintText: '192.168.1.100',
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                ),
                                prefixIcon: const Icon(
                                  Icons.wifi,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _testConnection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              'Connect',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Status Message
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isConnected
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isConnected
                                ? Colors.green.shade400
                                : Colors.red.shade400,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isConnected
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: _isConnected
                                  ? Colors.green.shade400
                                  : Colors.red.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _isConnected
                                      ? Colors.green.shade400
                                      : Colors.red.shade400,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Mode Control Section
                _buildGlassmorphismCard(
                  child: Column(
                    children: [
                      const Text(
                        'OPERATION MODE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: _buildModeButton(
                              'UP Mode',
                              'UP',
                              Icons.arrow_upward,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildModeButton(
                              'OFF Mode',
                              'OFF',
                              Icons.power_off,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Relay Buttons Grid (1-9, 0, *, #)
                _buildGlassmorphismCard(
                  child: Column(
                    children: [
                      const Text(
                        'RELAY CONTROLS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          // First row: 1, 2, 3
                          _buildRelayButton(
                            0,
                            '1',
                          ), // Button 1 controls relay 1
                          _buildRelayButton(
                            1,
                            '2',
                          ), // Button 2 controls relay 2
                          _buildRelayButton(
                            2,
                            '3',
                          ), // Button 3 controls relay 3
                          // Second row: 4, 5, 6
                          _buildRelayButton(
                            3,
                            '4',
                          ), // Button 4 controls relay 4
                          _buildRelayButton(
                            4,
                            '5',
                          ), // Button 5 controls relay 5
                          _buildRelayButton(
                            5,
                            '6',
                          ), // Button 6 controls relay 6
                          // Third row: 7, 8, 9
                          _buildRelayButton(
                            6,
                            '7',
                          ), // Button 7 controls relay 7
                          _buildRelayButton(
                            7,
                            '8',
                          ), // Button 8 controls relay 8
                          _buildRelayButton(
                            8,
                            '9',
                          ), // Button 9 controls relay 9
                          // Fourth row: *, 0, #
                          _buildSpecialButton('*', Colors.amber),
                          _buildRelayButton(
                            9,
                            '0',
                          ), // Button 0 controls relay 10
                          _buildSpecialButton('#', Colors.purpleAccent),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Dial Button
                _buildGlassmorphismCard(
                  child: Column(
                    children: [
                      const Text(
                        'DIAL CONTROL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ElevatedButton(
                          onPressed: _isConnected ? _controlDialRelay : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.6),
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(20),
                            minimumSize: const Size(80, 80),
                            elevation: 10,
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.adjust, size: 24),
                              SizedBox(height: 4),
                              Text(
                                'DIAL',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Instructions
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  child: Text(
                    'Note: Relays 1-10: 500ms pulse | Dial: 1s pulse | Mode: Controls GPIO 15,4,5',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for consistent button style
  Widget _buildModeButton(String text, String mode, IconData icon) {
    bool isSelected = _currentMode == mode;
    return ElevatedButton(
      onPressed: _isConnected
          ? (mode == 'UP' ? _setUpMode : _setOffMode)
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.cyan : Colors.blueGrey.shade800,
        foregroundColor: isSelected ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  // Helper method for relay buttons - now with circular shape
  Widget _buildRelayButton(int relayNumber, String displayText) {
    return Container(
      margin: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: _isConnected ? () => _controlRelay(relayNumber) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              relayNumber ==
                  9 // 0 button is the 10th relay
              ? Colors.deepOrangeAccent
              : Colors.blueAccent,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(16),
          elevation: 8,
        ),
        child: Text(
          displayText,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Helper method for special buttons (* and #)
  Widget _buildSpecialButton(String symbol, Color color) {
    return Container(
      margin: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: null, // These buttons are not functional
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.6),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(16),
          elevation: 8,
        ),
        child: Text(
          symbol,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Helper method for glassmorphism card effect
  Widget _buildGlassmorphismCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }
}
