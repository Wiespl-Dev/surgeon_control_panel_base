import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wiespl_surgeon_panel/services/esptwo.dart';

class GasStatusPage extends StatefulWidget {
  @override
  _GasStatusPageState createState() => _GasStatusPageState();
}

class _GasStatusPageState extends State<GasStatusPage> {
  List<GasStatus> _gasStatusList = [];
  String _lastProcessedData = '';

  // Gas configuration - Only 6 sensors
  final List<Map<String, dynamic>> _gasConfigs = [
    {"name": "Oxygen", "icon": Icons.air},
    {"name": "Nitrous", "icon": Icons.waves},
    {"name": "CO2", "icon": Icons.waves},
    {"name": "Vacuum", "icon": Icons.arrow_upward},
    {"name": "Air Bar 4", "icon": Icons.whatshot},
    {"name": "Air Bar 7", "icon": Icons.fireplace},
  ];

  // Audio player for alerts
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlertPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeDefaultGasStatus();
    _setupDataListener();
  }

  @override
  void dispose() {
    _stopAudio();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _initializeDefaultGasStatus() {
    _gasStatusList = List.generate(
      6,
      (index) => GasStatus(
        name: _gasConfigs[index]["name"] as String,
        sensorNumber: index + 1,
        status: "WAITING DATA",
        color: Colors.orange,
        faultBit: -1,
        icon: _gasConfigs[index]["icon"] as IconData,
      ),
    );
  }

  void _setupDataListener() {
    // Listen for ESP32 data updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final esp32Provider = Provider.of<ESP32Provider>(context, listen: false);

      // Start polling if not already started
      esp32Provider.startPolling();

      // Request initial data
      esp32Provider.refreshData();
    });
  }

  // Parse gas data from ESP32 sensor faults
  void _parseGasDataFromESP32(ESP32Provider esp32Provider) {
    // Get sensor faults directly from provider
    List<String> sensorFaults = esp32Provider.sensorFaults;

    List<GasStatus> updatedList = [];

    // Process sensors 1-6
    for (int i = 1; i <= 6; i++) {
      int faultBit = -1;
      String status;
      Color color;

      // Get fault bit from sensor faults array
      if (i <= sensorFaults.length) {
        try {
          faultBit = int.tryParse(sensorFaults[i - 1]) ?? -1;
        } catch (e) {
          faultBit = -1;
        }
      }

      // Logic: 1 = EMPTY, 0 = FULL
      if (faultBit == 1) {
        status = "EMPTY";
        color = Colors.red;
      } else if (faultBit == 0) {
        status = "FULL";
        color = Colors.green;
      } else {
        status = "NO DATA";
        color = Colors.orange;
      }

      updatedList.add(
        GasStatus(
          name: _gasConfigs[i - 1]["name"] as String,
          sensorNumber: i,
          status: status,
          color: color,
          faultBit: faultBit,
          icon: _gasConfigs[i - 1]["icon"] as IconData,
        ),
      );
    }

    // Only update if the list has changed
    bool hasChanged = false;
    if (_gasStatusList.length != updatedList.length) {
      hasChanged = true;
    } else {
      for (int i = 0; i < _gasStatusList.length; i++) {
        if (_gasStatusList[i].faultBit != updatedList[i].faultBit ||
            _gasStatusList[i].status != updatedList[i].status) {
          hasChanged = true;
          break;
        }
      }
    }

    if (hasChanged) {
      // Update state
      if (mounted) {
        setState(() {
          _gasStatusList = updatedList;
        });
      }

      // Check and play alert dynamically
      _checkAndPlayAlert();
    }
  }

  // Alternative: Parse from raw data if needed
  void _parseGasDataFromRaw(String rawData) {
    print('🔍 Parsing gas data: $rawData');

    try {
      // Clean the data
      String cleanData = rawData.replaceAll('{', '').replaceAll('}', '').trim();

      // Skip if empty
      if (cleanData.isEmpty) return;

      List<String> pairs = cleanData.split(',');
      print('📊 Split into ${pairs.length} pairs');

      Map<String, String> dataMap = {};

      for (String pair in pairs) {
        if (pair.contains(':')) {
          List<String> keyValue = pair.split(':');
          if (keyValue.length == 2) {
            String key = keyValue[0].trim();
            String value = keyValue[1].trim();
            dataMap[key] = value;
            print('   $key: $value');
          }
        }
      }

      List<GasStatus> updatedList = [];

      // Process sensors 1-6
      for (int i = 1; i <= 6; i++) {
        String faultKey = 'F_Sensor_${i}_FAULT_BIT';
        String status;
        Color color;
        int faultBit = -1;

        if (dataMap.containsKey(faultKey)) {
          try {
            faultBit = int.tryParse(dataMap[faultKey]!) ?? -1;
            print('Sensor $i fault bit: $faultBit');
          } catch (e) {
            print('Error parsing fault bit for sensor $i: $e');
            faultBit = -1;
          }

          // Logic: 1 = EMPTY, 0 = FULL
          if (faultBit == 1) {
            status = "EMPTY";
            color = Colors.red;
          } else if (faultBit == 0) {
            status = "FULL";
            color = Colors.green;
          } else if (faultBit == -1) {
            status = "NO DATA";
            color = Colors.orange;
          } else {
            status = "UNKNOWN";
            color = Colors.grey;
          }
        } else {
          status = "NO DATA";
          color = Colors.orange;
        }

        updatedList.add(
          GasStatus(
            name: _gasConfigs[i - 1]["name"] as String,
            sensorNumber: i,
            status: status,
            color: color,
            faultBit: faultBit,
            icon: _gasConfigs[i - 1]["icon"] as IconData,
          ),
        );
      }

      // Update state
      if (mounted) {
        setState(() {
          _gasStatusList = updatedList;
        });
      }

      // Check and play alert dynamically
      _checkAndPlayAlert();
    } catch (e) {
      print('❌ Error parsing gas data: $e');
    }
  }

  void _checkAndPlayAlert() {
    // Get all EMPTY gases
    List<GasStatus> emptyGases = _gasStatusList
        .where((gas) => gas.status == "EMPTY")
        .toList();

    print('🔊 Empty gases count: ${emptyGases.length}');

    if (emptyGases.isNotEmpty && !_isAlertPlaying) {
      print('🔊 Starting alert for empty gases');
      setState(() {
        _isAlertPlaying = true;
      });
      _playLoopAlert(emptyGases);
    } else if (emptyGases.isEmpty && _isAlertPlaying) {
      print('🔊 Stopping alert - no empty gases');
      setState(() {
        _isAlertPlaying = false;
      });
      _stopAudio();
    }
  }

  Future<void> _playLoopAlert(List<GasStatus> emptyGases) async {
    Map<String, String> gasAudioMap = {
      'Oxygen': 'assets/audio/Oxygen.mp3',
      'Vacuum': 'assets/audio/VaccumError.mp3',
      'Nitrous': 'assets/audio/Nitrogen.mp3',
      'Air Bar 4': 'assets/audio/AirBar4.mp3',
      'Air Bar 7': 'assets/audio/AirBar4.mp3',
      'CO2': 'assets/audio/Nitrogen.mp3', // Fallback
    };

    List<String> alertFiles = [];

    for (var gas in emptyGases) {
      String? audioFile = gasAudioMap[gas.name];
      if (audioFile != null && !alertFiles.contains(audioFile)) {
        alertFiles.add(audioFile);
      }
    }

    print('🔊 Alert files to play: $alertFiles');

    if (alertFiles.isEmpty) return;

    int index = 0;

    while (_isAlertPlaying && alertFiles.isNotEmpty) {
      String currentFile = alertFiles[index];
      print('🔊 Playing alert: $currentFile');

      try {
        await _audioPlayer.play(
          AssetSource(currentFile.replaceFirst('assets/', '')),
        );
        await _audioPlayer.onPlayerComplete.first;
        index = (index + 1) % alertFiles.length;
      } catch (e) {
        print('❌ Error playing audio: $e');
        break;
      }
    }

    print('🔊 Alert loop ended');
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MGPS', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 18, 39, 41),
        elevation: 0,
        actions: [_buildConnectionStatus()],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 18, 39, 41),
              Color.fromARGB(255, 25, 60, 63),
            ],
          ),
        ),
        child: Column(
          children: [
            // Connection status using Consumer
            Consumer<ESP32Provider>(
              builder: (context, esp32Provider, child) {
                if (!esp32Provider.isConnected) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.red.withOpacity(0.2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'ESP32 Disconnected - Trying to connect...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Data display section
            Expanded(
              child: Consumer<ESP32Provider>(
                builder: (context, esp32Provider, child) {
                  // Whenever ESP32 data updates, parse gas data
                  // But don't call setState here - let the provider trigger rebuild
                  if (esp32Provider.isConnected) {
                    // This will update _gasStatusList without causing infinite loop
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _parseGasDataFromESP32(esp32Provider);
                      }
                    });
                  }

                  return _buildGasGrid();
                },
              ),
            ),

            // Back button
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0, left: 10),
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
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Consumer<ESP32Provider>(
      builder: (context, esp32Provider, child) {
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              Icon(
                esp32Provider.isConnected ? Icons.wifi : Icons.wifi_off,
                color: esp32Provider.isConnected ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGasGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
        ),
        itemCount: _gasStatusList.length,
        itemBuilder: (context, index) {
          return _buildGasCard(_gasStatusList[index]);
        },
      ),
    );
  }

  Widget _buildGasCard(GasStatus gas) {
    return Card(
      color: const Color.fromARGB(29, 255, 255, 255),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gas.color.withOpacity(0.4), width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(gas.icon, size: 28, color: gas.color),
              const SizedBox(height: 6),
              Text(
                gas.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: gas.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gas.color, width: 1),
                ),
                child: Text(
                  gas.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Sensor ${gas.sensorNumber}',
                style: const TextStyle(fontSize: 9, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GasStatus {
  final String name;
  final int sensorNumber;
  final String status;
  final Color color;
  final int faultBit;
  final IconData icon;

  GasStatus({
    required this.name,
    required this.sensorNumber,
    required this.status,
    required this.color,
    required this.faultBit,
    required this.icon,
  });
}
// import 'dart:async';
// import 'dart:typed_data';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:http/http.dart' as http;
// import 'package:wiespl_contrl_panel/services/usb_services.dart';

// class GasStatusPage extends StatefulWidget {
//   @override
//   _GasStatusPageState createState() => _GasStatusPageState();
// }

// class _GasStatusPageState extends State<GasStatusPage> {
//   List<GasStatus> _gasStatusList = [];

//   // --- ESP32 Configuration ---
//   final String esp32BaseUrl = 'http://192.168.0.100:8080';
//   Timer? _dataTimer;
//   String _esp32Status = "Connecting...";
//   bool _useEsp32 =
//       false; // Start with false, will be determined by connection check

//   // Gas configuration
//   final List<Map<String, dynamic>> _gasConfigs = [
//     {"name": "Oxygen", "icon": Icons.air},
//     {"name": "Nitrous", "icon": Icons.waves},
//     {"name": "CO2", "icon": Icons.cloud},
//     {"name": "Vacuum", "icon": Icons.arrow_upward},
//     // {"name": "Normal Air", "icon": Icons.brightness_1},
//     {"name": "Air Bar 4", "icon": Icons.whatshot},
//     {"name": "Air Bar 7", "icon": Icons.fireplace},
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _initializeDefaultGasStatus();
//     _checkConnectionMethod();
//     // _startDataPolling();
//     _fetchData();
//   }

//   void _checkConnectionMethod() {
//     final usbProvider = Provider.of<GlobalUsbProvider>(context, listen: false);
//     setState(() {
//       _useEsp32 = !usbProvider.isConnected;
//     });
//     print("Connection Method: ${_useEsp32 ? 'ESP32' : 'USB'}");
//   }

//   @override
//   void dispose() {
//     _dataTimer?.cancel();
//     super.dispose();
//   }

//   void _initializeDefaultGasStatus() {
//     _gasStatusList = List.generate(
//       6,
//       (index) => GasStatus(
//         name: _gasConfigs[index]["name"] as String,
//         sensorNumber: index + 1,
//         status: "WAITING DATA",
//         color: Colors.orange,
//         faultBit: -1,
//         icon: _gasConfigs[index]["icon"] as IconData,
//       ),
//     );
//   }

//   // void _startDataPolling() {
//   //   _dataTimer?.cancel();
//   //   _fetchData();
//   //   _dataTimer = Timer.periodic(Duration(seconds: 3), (timer) {
//   //     _fetchData();
//   //   });
//   // }

//   Future<void> _fetchData() async {
//     if (_useEsp32) {
//       await _fetchDataFromESP32();
//     } else {
//       await _fetchDataFromUSB();
//     }
//   }

//   Future<void> _fetchDataFromESP32() async {
//     try {
//       final response = await http
//           .get(Uri.parse('$esp32BaseUrl/data'))
//           .timeout(const Duration(seconds: 2));

//       if (response.statusCode == 200) {
//         if (mounted) {
//           _parseGasData(response.body);
//           setState(() {
//             _esp32Status = "Connected";
//           });
//         }
//       } else {
//         throw Exception('Failed to load data');
//       }
//     } catch (e) {
//       if (mounted) {
//         print("ESP32 Fetch Error: $e");
//         setState(() {
//           _esp32Status = "Connection Failed";
//         });
//       }
//     }
//   }

//   Future<void> _fetchDataFromUSB() async {
//     try {
//       final usbProvider = Provider.of<GlobalUsbProvider>(
//         context,
//         listen: false,
//       );

//       // Request gas sensor data from USB
//       usbProvider.sendCompleteStructure();

//       // Simulate parsing USB data - you'll need to replace this with actual USB data parsing
//       // For now, we'll create mock data to show it's working
//       _parseUSBGasData();
//     } catch (e) {
//       print("USB Fetch Error: $e");
//       if (mounted) {
//         setState(() {
//           // Optionally fall back to ESP32 if USB fails
//           _useEsp32 = true;
//           _esp32Status = "USB Failed, switching to ESP32";
//         });
//       }
//     }
//   }

//   void _parseUSBGasData() {
//     try {
//       // TODO: Replace this with actual USB data parsing from your GlobalUsbProvider
//       // For now, creating mock data to demonstrate USB functionality

//       List<GasStatus> updatedList = [];
//       for (int i = 1; i <= _gasConfigs.length; i++) {
//         String status;
//         Color color;
//         int faultBit;

//         // Mock data - replace with actual USB data
//         // Simulating random status for demonstration
//         if (i == 1) {
//           status = "FULL";
//           color = Colors.green;
//           faultBit = 0;
//         } else {
//           status = "EMPTY";
//           color = Colors.red;
//           faultBit = 1;
//         }

//         updatedList.add(
//           GasStatus(
//             name: _gasConfigs[i - 1]["name"] as String,
//             sensorNumber: i,
//             status: status,
//             color: color,
//             faultBit: faultBit,
//             icon: _gasConfigs[i - 1]["icon"] as IconData,
//           ),
//         );
//       }

//       if (mounted) {
//         setState(() {
//           _gasStatusList = updatedList;
//         });
//       }

//       _checkAndPlayAlert();

//       print("USB Data Parsed Successfully");
//     } catch (e) {
//       print('Error parsing USB gas data: $e');
//     }
//   }

//   void _parseGasData(String rawData) {
//     try {
//       // Handle both JSON and key-value format
//       String cleanData = rawData;
//       if (rawData.startsWith('{') && rawData.endsWith('}')) {
//         cleanData = rawData.substring(1, rawData.length - 1);
//       }

//       List<String> pairs = cleanData.split(',');

//       Map<String, String> dataMap = {};

//       for (String pair in pairs) {
//         if (pair.contains(':')) {
//           List<String> keyValue = pair.split(':');
//           if (keyValue.length == 2) {
//             dataMap[keyValue[0].trim()] = keyValue[1].trim();
//           }
//         }
//       }

//       List<GasStatus> updatedList = [];
//       for (int i = 1; i <= _gasConfigs.length; i++) {
//         String faultKey = 'F_Sensor_${i}_FAULT_BIT';
//         String status;
//         Color color;
//         int faultBit = -1;

//         if (dataMap.containsKey(faultKey)) {
//           faultBit = int.tryParse(dataMap[faultKey]!) ?? 1;

//           if (faultBit == 1) {
//             status = "EMPTY";
//             color = Colors.red;
//           } else if (faultBit == 0) {
//             status = "FULL";
//             color = Colors.green;
//           } else {
//             status = "UNKNOWN";
//             color = Colors.grey;
//           }
//         } else {
//           status = "NO DATA";
//           color = Colors.orange;
//         }

//         updatedList.add(
//           GasStatus(
//             name: _gasConfigs[i - 1]["name"] as String,
//             sensorNumber: i,
//             status: status,
//             color: color,
//             faultBit: faultBit,
//             icon: _gasConfigs[i - 1]["icon"] as IconData,
//           ),
//         );
//       }

//       if (mounted) {
//         setState(() {
//           _gasStatusList = updatedList;
//         });
//       }

//       _checkAndPlayAlert();
//     } catch (e) {
//       print('Error parsing gas data: $e');
//     }
//   }

//   // Audio alert logic - uses GlobalUsbProvider for audio only
//   void _checkAndPlayAlert() {
//     final globalUsbProvider = Provider.of<GlobalUsbProvider>(
//       context,
//       listen: false,
//     );

//     List<GasStatus> emptyGases = _gasStatusList
//         .where((gas) => gas.status == "EMPTY")
//         .toList();

//     if (emptyGases.isNotEmpty && !globalUsbProvider.isAlertPlaying) {
//       globalUsbProvider.setAlertPlaying(true);
//       _playLoopAlert(emptyGases);
//     } else if (emptyGases.isEmpty && globalUsbProvider.isAlertPlaying) {
//       globalUsbProvider.setAlertPlaying(false);
//       globalUsbProvider.stopAudio();
//     }
//   }

//   Future<void> _playLoopAlert(List<GasStatus> emptyGases) async {
//     final globalUsbProvider = Provider.of<GlobalUsbProvider>(
//       context,
//       listen: false,
//     );

//     Map<String, String> gasAudioMap = {
//       'Oxygen': 'assets/audio/Oxygen.mp3',
//       'Vacuum': 'assets/audio/VaccumError.mp3',
//       'Carbon Dioxide': 'assets/audio/CO2.mp3',
//       'Nitrogen': 'assets/audio/Nitrogen.mp3',
//       'Air Bar 3': 'assets/audio/AirBar3.mp3',
//       'Air Bar 7': 'assets/audio/AirBar7.mp3',
//       'Normal Air': 'assets/audio/NormalAir.mp3',
//     };

//     List<String> alertFiles = emptyGases
//         .map((gas) => gasAudioMap[gas.name])
//         .whereType<String>()
//         .toList();

//     int index = 0;

//     while (globalUsbProvider.isAlertPlaying && alertFiles.isNotEmpty) {
//       String currentFile = alertFiles[index];
//       await globalUsbProvider.audioPlayer.play(
//         AssetSource(currentFile.replaceFirst('assets/', '')),
//       );
//       await globalUsbProvider.audioPlayer.onPlayerComplete.first;
//       index = (index + 1) % alertFiles.length;
//     }
//   }

//   // Manual refresh method
//   Future<void> _manualRefresh() async {
//     if (_useEsp32) {
//       setState(() {
//         _esp32Status = "Refreshing...";
//       });
//       await _fetchDataFromESP32();
//       _showSuccessSnackbar("ESP32 data refreshed");
//     } else {
//       await _fetchDataFromUSB();
//       _showSuccessSnackbar("USB data refreshed");
//     }
//   }

//   void _showSuccessSnackbar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.green,
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }

//   void _showErrorSnackbar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.red,
//         duration: const Duration(seconds: 3),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final usbProvider = Provider.of<GlobalUsbProvider>(context);

//     // Update connection method based on current USB status
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_useEsp32 != !usbProvider.isConnected) {
//         _checkConnectionMethod();
//         // _startDataPolling();
//         _fetchData();
//       }
//     });

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('MGPS', style: TextStyle(color: Colors.white)),
//         backgroundColor: const Color.fromARGB(255, 18, 39, 41),
//         elevation: 0,
//         iconTheme: const IconThemeData(color: Colors.white),
//         actions: [
//           _buildConnectionStatus(usbProvider),
//           IconButton(
//             icon: Icon(Icons.refresh, color: Colors.white),
//             onPressed: _manualRefresh,
//             tooltip: "Refresh Data",
//           ),
//         ],
//       ),
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Color.fromARGB(255, 18, 39, 41),
//               Color.fromARGB(255, 25, 60, 63),
//             ],
//           ),
//         ),
//         child: Column(
//           children: [
//             // Connection status banner
//             if (_esp32Status != "Connected" && _useEsp32)
//               Container(
//                 width: double.infinity,
//                 padding: EdgeInsets.all(8),
//                 color: Colors.red.withOpacity(0.2),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.wifi_off, color: Colors.red, size: 16),
//                     SizedBox(width: 8),
//                     Text(
//                       'ESP32: $_esp32Status',
//                       style: TextStyle(color: Colors.white),
//                     ),
//                   ],
//                 ),
//               ),
//             // USB connection banner
//             if (!_useEsp32)
//               Container(
//                 width: double.infinity,
//                 padding: EdgeInsets.all(8),
//                 color: Colors.green.withOpacity(0.2),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.usb, color: Colors.green, size: 16),
//                     SizedBox(width: 8),
//                     Text(
//                       'Using USB Connection',
//                       style: TextStyle(color: Colors.white),
//                     ),
//                   ],
//                 ),
//               ),
//             Expanded(child: _buildGasGrid()),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildConnectionStatus(GlobalUsbProvider usbProvider) {
//     bool isConnected = _useEsp32
//         ? _esp32Status == "Connected"
//         : usbProvider.isConnected;
//     Color statusColor = isConnected ? Colors.green : Colors.red;
//     IconData statusIcon = _useEsp32
//         ? (isConnected ? Icons.wifi : Icons.wifi_off)
//         : (isConnected ? Icons.usb : Icons.usb_off);

//     return Padding(
//       padding: EdgeInsets.only(right: 8),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//             decoration: BoxDecoration(
//               color: statusColor.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: statusColor, width: 1),
//             ),
//             child: Row(
//               children: [
//                 Icon(statusIcon, color: statusColor, size: 16),
//                 SizedBox(width: 4),
//                 Text(
//                   _useEsp32 ? "ESP32" : "USB",
//                   style: TextStyle(
//                     color: statusColor,
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildGasGrid() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16.0),
//       child: GridView.builder(
//         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 4,
//           crossAxisSpacing: 12,
//           mainAxisSpacing: 12,
//           childAspectRatio: 1.4,
//         ),
//         itemCount: _gasStatusList.length,
//         itemBuilder: (context, index) {
//           return _buildGasCard(_gasStatusList[index]);
//         },
//       ),
//     );
//   }

//   Widget _buildGasCard(GasStatus gas) {
//     return Card(
//       color: const Color.fromARGB(29, 255, 255, 255),
//       elevation: 6,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Container(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: gas.color.withOpacity(0.4), width: 3),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(12.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(gas.icon, size: 28, color: gas.color),
//               SizedBox(height: 6),
//               Text(
//                 gas.name,
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//                 textAlign: TextAlign.center,
//                 maxLines: 2,
//               ),
//               SizedBox(height: 4),
//               Container(
//                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: gas.color.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: gas.color, width: 1),
//                 ),
//                 child: Text(
//                   gas.status,
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 10,
//                   ),
//                 ),
//               ),
//               SizedBox(height: 2),
//               Text(
//                 'Sensor ${gas.sensorNumber}',
//                 style: TextStyle(fontSize: 9, color: Colors.white),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class GasStatus {
//   final String name;
//   final int sensorNumber;
//   final String status;
//   final Color color;
//   final int faultBit;
//   final IconData icon;

//   GasStatus({
//     required this.name,
//     required this.sensorNumber,
//     required this.status,
//     required this.color,
//     required this.faultBit,
//     required this.icon,
//   });
// }
