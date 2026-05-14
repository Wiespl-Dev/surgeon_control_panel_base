import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiespl_surgeon_panel/services/esptwo.dart';

// GasStatus class definition
class GasStatus {
  final String name;
  final int sensorNumber;
  final String status;
  final Color color;
  final int faultBit;
  final IconData icon;

  GasStatus(
    this.name,
    this.sensorNumber,
    this.status,
    this.color,
    this.faultBit,
    this.icon,
  );
}

class GasStatusPage extends StatefulWidget {
  @override
  _GasStatusPageState createState() => _GasStatusPageState();
}

class _GasStatusPageState extends State<GasStatusPage> {
  List<GasStatus> _gasStatusList = [];
  bool _isEspInitialized = false;
  bool _isLoading = true;

  // Dynamic gas list - YOU decide the gases
  List<Map<String, dynamic>> _gasConfigs = [];

  // Available icons with names for better selection
  final List<Map<String, dynamic>> _availableIcons = [
    {"icon": Icons.air, "name": "Air"},
    {"icon": Icons.waves, "name": "Waves"},
    {"icon": Icons.whatshot, "name": "Hot"},
    {"icon": Icons.fireplace, "name": "Fire"},
    {"icon": Icons.arrow_upward, "name": "Upward"},
    {"icon": Icons.water_drop, "name": "Water"},
    {"icon": Icons.science, "name": "Science"},
    {"icon": Icons.medical_services, "name": "Medical"},
    {"icon": Icons.local_hospital, "name": "Hospital"},
    {"icon": Icons.biotech, "name": "Bio"},
    {"icon": Icons.gas_meter, "name": "Gas Meter"},
    {"icon": Icons.cleaning_services, "name": "Cleaning"},
    {"icon": Icons.thermostat, "name": "Temp"},
    {"icon": Icons.compress, "name": "Compress"},
    {"icon": Icons.coronavirus, "name": "Virus"},
  ];

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlertPlaying = false;

  List<String> _lastParsedFaults = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadGasConfigs();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final esp32Provider = Provider.of<ESP32Provider>(context, listen: false);
      await esp32Provider.initialize();

      setState(() {
        _isEspInitialized = true;
      });

      print(
        "✅ ESP32 Provider initialized in GasStatusPage with IP: ${esp32Provider.esp32IP}",
      );
      _startPeriodicPolling();
    });
  }

  Future<void> _loadGasConfigs() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    List<String>? savedGases = prefs.getStringList('gasConfigs');
    List<String>? savedIconIndices = prefs.getStringList(
      'gasIconIndices',
    ); // Store as StringList

    if (savedGases != null && savedGases.isNotEmpty) {
      // Load saved gases with their icons
      List<Map<String, dynamic>> loadedConfigs = [];
      for (int i = 0; i < savedGases.length; i++) {
        int iconIndex = 0;
        if (savedIconIndices != null && i < savedIconIndices.length) {
          iconIndex = int.tryParse(savedIconIndices[i]) ?? 0;
        } else {
          iconIndex = i % _availableIcons.length;
        }
        loadedConfigs.add({
          "name": savedGases[i],
          "icon": _availableIcons[iconIndex]["icon"],
          "iconIndex": iconIndex,
        });
      }
      setState(() {
        _gasConfigs = loadedConfigs;
      });
    } else {
      setState(() {
        _gasConfigs = [];
      });
    }

    _initializeGasStatus();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveGasConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> gasNames = _gasConfigs
        .map((gas) => gas["name"] as String)
        .toList();
    List<String> gasIconIndices = _gasConfigs
        .map((gas) => (gas["iconIndex"] as int).toString())
        .toList(); // Convert to String
    await prefs.setStringList('gasConfigs', gasNames);
    await prefs.setStringList(
      'gasIconIndices',
      gasIconIndices,
    ); // Save as StringList
  }

  Future<void> _addNewGas() async {
    TextEditingController nameController = TextEditingController();
    int selectedIconIndex = 0;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: EdgeInsets.all(20),
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add New Gas',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C6975),
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Gas Name',
                      hintText: 'Enter gas name (e.g., Nitrogen, Helium)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(
                        Icons.medical_services,
                        color: Color(0xFF2C6975),
                      ),
                    ),
                    style: TextStyle(color: Colors.black),
                    autofocus: true,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Select Icon',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C6975),
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    height: 200,
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        childAspectRatio: 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _availableIcons.length,
                      itemBuilder: (context, index) {
                        bool isSelected = selectedIconIndex == index;
                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              selectedIconIndex = index;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color(0xFF2C6975).withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Color(0xFF2C6975)
                                    : Colors.grey.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _availableIcons[index]["icon"],
                                  size: 32,
                                  color: isSelected
                                      ? Color(0xFF2C6975)
                                      : Colors.grey,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _availableIcons[index]["name"],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? Color(0xFF2C6975)
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: TextStyle(fontSize: 16)),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          if (nameController.text.isNotEmpty) {
                            setState(() {
                              _gasConfigs.add({
                                "name": nameController.text,
                                "icon":
                                    _availableIcons[selectedIconIndex]["icon"],
                                "iconIndex": selectedIconIndex,
                              });
                            });
                            _saveGasConfigs();
                            _initializeGasStatus();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added ${nameController.text}'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2C6975),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          'Add Gas',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editGasName(int index) async {
    TextEditingController controller = TextEditingController(
      text: _gasConfigs[index]["name"],
    );
    int selectedIconIndex = _gasConfigs[index]["iconIndex"];

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: EdgeInsets.all(20),
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Edit Gas',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C6975),
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Gas Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.edit, color: Color(0xFF2C6975)),
                    ),
                    style: TextStyle(color: Colors.black),
                    autofocus: true,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Change Icon',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C6975),
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    height: 200,
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        childAspectRatio: 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _availableIcons.length,
                      itemBuilder: (context, iconIndex) {
                        bool isSelected = selectedIconIndex == iconIndex;
                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              selectedIconIndex = iconIndex;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color(0xFF2C6975).withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Color(0xFF2C6975)
                                    : Colors.grey.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _availableIcons[iconIndex]["icon"],
                                  size: 32,
                                  color: isSelected
                                      ? Color(0xFF2C6975)
                                      : Colors.grey,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _availableIcons[iconIndex]["name"],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? Color(0xFF2C6975)
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: TextStyle(fontSize: 16)),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          if (controller.text.isNotEmpty) {
                            setState(() {
                              _gasConfigs[index]["name"] = controller.text;
                              _gasConfigs[index]["icon"] =
                                  _availableIcons[selectedIconIndex]["icon"];
                              _gasConfigs[index]["iconIndex"] =
                                  selectedIconIndex;
                            });
                            _saveGasConfigs();
                            _initializeGasStatus();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Updated to ${controller.text}'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2C6975),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          'Save Changes',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteGas(int index) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Gas', style: TextStyle(color: Colors.red)),
        content: Text(
          'Are you sure you want to delete ${_gasConfigs[index]["name"]}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _gasConfigs.removeAt(index);
              });
              _saveGasConfigs();
              _initializeGasStatus();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gas deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _initializeGasStatus() {
    setState(() {
      _gasStatusList = List.generate(_gasConfigs.length, (index) {
        return GasStatus(
          _gasConfigs[index]["name"] as String,
          index + 1,
          "WAITING DATA",
          Colors.orange,
          -1,
          _gasConfigs[index]["icon"] as IconData,
        );
      });
    });
  }

  void _startPeriodicPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final esp32Provider = Provider.of<ESP32Provider>(context, listen: false);
      if (esp32Provider.isConnected && _gasConfigs.isNotEmpty) {
        _parseGasDataFromESP32(esp32Provider);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _isAlertPlaying = false;
    _audioPlayer.stop();
    _audioPlayer.dispose();

    final esp32Provider = Provider.of<ESP32Provider>(context, listen: false);
    esp32Provider.stopPolling();

    super.dispose();
  }

  void _parseGasDataFromESP32(ESP32Provider esp32Provider) {
    List<String> sensorFaults = esp32Provider.sensorFaults;

    if (_lastParsedFaults.length == sensorFaults.length) {
      bool same = true;
      for (int i = 0; i < sensorFaults.length; i++) {
        if (_lastParsedFaults[i] != sensorFaults[i]) {
          same = false;
          break;
        }
      }
      if (same) return;
    }

    _lastParsedFaults = List.from(sensorFaults);

    List<GasStatus> updatedList = [];

    for (int i = 1; i <= _gasConfigs.length; i++) {
      int faultBit = -1;
      String status;
      Color color;

      if (i <= sensorFaults.length) {
        faultBit = int.tryParse(sensorFaults[i - 1]) ?? -1;
      }

      if (faultBit == 0) {
        status = "EMPTY";
        color = Colors.red;
      } else if (faultBit == 1) {
        status = "FULL";
        color = Colors.green;
      } else {
        status = "NO DATA";
        color = Colors.orange;
      }

      updatedList.add(
        GasStatus(
          _gasConfigs[i - 1]["name"] as String,
          i,
          status,
          color,
          faultBit,
          _gasConfigs[i - 1]["icon"] as IconData,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _gasStatusList = updatedList;
      });
      _checkAndPlayAlert();
    }
  }

  void _checkAndPlayAlert() {
    List<GasStatus> emptyGases = _gasStatusList
        .where((gas) => gas.status == "EMPTY")
        .toList();

    if (emptyGases.isNotEmpty && !_isAlertPlaying) {
      setState(() => _isAlertPlaying = true);
      _playLoopAlert(emptyGases);
    } else if (emptyGases.isEmpty && _isAlertPlaying) {
      setState(() => _isAlertPlaying = false);
      _audioPlayer.stop();
    }
  }

  Future<void> _playLoopAlert(List<GasStatus> emptyGases) async {
    final Map<String, String> gasAudioMap = {
      'Oxygen': 'audio/Oxygen.mp3',
      'Vacuum': 'audio/VaccumError.mp3',
      'N2O': 'audio/Nitrogen.mp3',
      'AGSS': 'audio/Nitrogen.mp3',
      'Air Bar 4': 'audio/AirBar4.mp3',
      'Air Bar 7': 'audio/AirBar4.mp3',
      'CO2': 'audio/Nitrogen.mp3',
    };

    List<String> alertFiles = [];
    for (var gas in emptyGases) {
      final audioFile = gasAudioMap[gas.name];
      if (audioFile != null && !alertFiles.contains(audioFile)) {
        alertFiles.add(audioFile);
      }
    }

    if (alertFiles.isEmpty) {
      _isAlertPlaying = false;
      return;
    }

    int index = 0;

    while (_isAlertPlaying && mounted && alertFiles.isNotEmpty) {
      try {
        await _audioPlayer.play(AssetSource(alertFiles[index]));
        await _audioPlayer.onPlayerComplete.first;
        index = (index + 1) % alertFiles.length;
      } catch (e) {
        debugPrint('❌ Error playing audio: $e');
        break;
      }
    }

    _isAlertPlaying = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MGPS', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 18, 39, 41),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
            onPressed: _addNewGas,
            tooltip: 'Add Gas',
          ),
          _buildConnectionStatus(),
        ],
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
            if (!_isEspInitialized)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.blue.withOpacity(0.2),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                    const SizedBox(height: 8),
                    Consumer<ESP32Provider>(
                      builder: (context, esp32Provider, child) {
                        return Text(
                          'Connecting to ESP32 at ${esp32Provider.esp32IP}...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

            Consumer<ESP32Provider>(
              builder: (context, esp32Provider, child) {
                if (_isEspInitialized && !esp32Provider.isConnected) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.red.withOpacity(0.2),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'ESP32 Disconnected - Trying to reconnect...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            if (_gasConfigs.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.blue.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Tap + to add gas | Long press gas to edit/delete',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : _buildMainContent(),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0, left: 10),
                  child: ElevatedButton(
                    onPressed: () {
                      _pollingTimer?.cancel();
                      Navigator.pop(context);
                    },
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

  Widget _buildMainContent() {
    if (_gasConfigs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_services,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            SizedBox(height: 20),
            Text(
              'No Gases Added',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Tap the + button to add gases',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (!_isEspInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 20),
            Consumer<ESP32Provider>(
              builder: (context, esp32Provider, child) {
                return Text(
                  'Initializing ESP32 Connection...\nIP: ${esp32Provider.esp32IP}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                );
              },
            ),
          ],
        ),
      );
    }

    return _buildGasGrid();
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
                size: 20,
              ),
              if (!_isEspInitialized) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGasGrid() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemCount: _gasStatusList.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onLongPress: () => _showGasOptionsDialog(index),
            child: _buildGasCard(_gasStatusList[index]),
          );
        },
      ),
    );
  }

  void _showGasOptionsDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              _gasConfigs[index]["icon"],
              color: Color(0xFF2C6975),
              size: 28,
            ),
            SizedBox(width: 10),
            Text(_gasConfigs[index]["name"]),
          ],
        ),
        content: Text('What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editGasName(index);
            },
            child: Text('Edit', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteGas(index);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildGasCard(GasStatus gas) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: gas.color.withOpacity(0.5), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(gas.icon, size: 40, color: gas.color),
              const SizedBox(height: 10),
              Text(
                gas.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: gas.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: gas.color, width: 1),
                ),
                child: Text(
                  gas.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sensor ${gas.sensorNumber}',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
