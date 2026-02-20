// // humidity_state.dart
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:usb_serial/usb_serial.dart';
// import 'dart:typed_data';

// class HumidityState with ChangeNotifier {
//   double _pendingHumidity = 50.0;
//   String? lastReceivedValue;
//   String? lastSentMessage;
//   String humidity = "--";

//   UsbPort? _port;
//   String usbStatus = "Disconnected";
//   bool isConnected = false;
//   String _incomingBuffer = "";

//   late SharedPreferences _prefs;

//   // Getters
//   double get pendingHumidity => _pendingHumidity;
//   String get currentHumidity => humidity;

//   // Initialize shared preferences
//   Future<void> initSharedPreferences() async {
//     _prefs = await SharedPreferences.getInstance();
//     _loadSavedValues();
//   }

//   void _loadSavedValues() {
//     humidity = _prefs.getString('current_humidity') ?? "--";
//     _pendingHumidity = _prefs.getDouble('setpoint_humidity') ?? 50.0;
//     notifyListeners();

//     print(
//       "Loaded saved values - Current: $humidity, Setpoint: $_pendingHumidity",
//     );
//   }

//   void _saveCurrentHumidity(String value) {
//     _prefs.setString('current_humidity', value);
//     print("Saved current humidity: $value");
//   }

//   void _saveSetpointHumidity(double value) {
//     _prefs.setDouble('setpoint_humidity', value);
//     print("Saved setpoint humidity: $value");
//   }

//   // Update pending humidity
//   void updatePendingHumidity(double value) {
//     _pendingHumidity = value.clamp(0.0, 100.0);
//     notifyListeners();
//   }

//   // USB Methods
//   Future<void> initUsb() async {
//     try {
//       usbStatus = "Scanning for USB devices...";
//       notifyListeners();

//       List<UsbDevice> devices = await UsbSerial.listDevices();
//       print("Found ${devices.length} USB devices");

//       if (devices.isEmpty) {
//         usbStatus = "No USB devices found";
//         isConnected = false;
//         notifyListeners();
//         return;
//       }

//       UsbDevice device = devices.first;
//       print("Connecting to: ${device.deviceName}");

//       usbStatus = "Connecting to ${device.deviceName}...";
//       notifyListeners();

//       _port = await device.create();
//       bool open = await _port!.open();

//       if (open) {
//         await _port!.setDTR(true);
//         await _port!.setRTS(true);
//         await _port!.setPortParameters(9600, 8, 1, 0);

//         usbStatus = "Connected to ${device.deviceName}";
//         isConnected = true;
//         notifyListeners();

//         print("USB connected successfully");
//         _port!.inputStream?.listen(_onDataReceived);
//       } else {
//         usbStatus = "Failed to open USB port";
//         isConnected = false;
//         notifyListeners();
//       }
//     } catch (e) {
//       print("USB Error: $e");
//       usbStatus = "Error: $e";
//       isConnected = false;
//       notifyListeners();
//     }
//   }

//   void _onDataReceived(Uint8List data) {
//     String str = String.fromCharCodes(data);
//     print("Received RAW chunk: $str");

//     _incomingBuffer += str;

//     if (_incomingBuffer.contains('\n') ||
//         (_incomingBuffer.startsWith('{') && _incomingBuffer.contains('}'))) {
//       List<String> messages = _incomingBuffer.split('\n');

//       for (int i = 0; i < messages.length - 1; i++) {
//         String completeMessage = messages[i].trim();
//         if (completeMessage.isNotEmpty) {
//           _processCompleteMessage(completeMessage);
//         }
//       }

//       _incomingBuffer = messages.last;
//     }

//     if (_incomingBuffer.startsWith('{') && _incomingBuffer.endsWith('}')) {
//       _processCompleteMessage(_incomingBuffer);
//       _incomingBuffer = "";
//     }
//   }

//   void _processCompleteMessage(String completeMessage) {
//     print("Processing complete message: $completeMessage");
//     lastReceivedValue = completeMessage;
//     _parseStructuredData(completeMessage);
//   }

//   void _parseStructuredData(String data) {
//     try {
//       print("Parsing complete message: $data");

//       if (data.startsWith('{') && data.endsWith('}')) {
//         String content = data.substring(1, data.length - 1);
//         List<String> pairs = content.split(',');

//         Map<String, dynamic> parsedData = {};

//         for (String pair in pairs) {
//           List<String> keyValue = pair.split(':');
//           if (keyValue.length == 2) {
//             String key = keyValue[0].trim();
//             String value = keyValue[1].trim();
//             parsedData[key] = value;
//           }
//         }

//         print("Parsed data: $parsedData");

//         // Parse current humidity (C_RH:295 = 29.5%)
//         if (parsedData.containsKey('C_RH')) {
//           String humStr = parsedData['C_RH'].toString();
//           if (humStr.length >= 2) {
//             String wholePart = humStr.substring(0, humStr.length - 1);
//             String decimalPart = humStr.substring(humStr.length - 1);
//             humidity = '$wholePart.$decimalPart';
//             print("Parsed humidity: $humidity%");
//             _saveCurrentHumidity(humidity);
//           } else {
//             humidity = humStr;
//             _saveCurrentHumidity(humidity);
//           }
//         } else {
//           print("C_RH key not found in parsed data");
//         }

//         // Parse set humidity (S_RH_SETPT:784 = 78.4%)
//         if (parsedData.containsKey('S_RH_SETPT')) {
//           String setHumStr = parsedData['S_RH_SETPT'].toString();
//           if (setHumStr.length >= 2) {
//             String wholePart = setHumStr.substring(0, setHumStr.length - 1);
//             String decimalPart = setHumStr.substring(setHumStr.length - 1);
//             _pendingHumidity = double.parse(
//               "$wholePart.$decimalPart",
//             ).toDouble();
//             print("Parsed set humidity: $_pendingHumidity%");
//             _saveSetpointHumidity(_pendingHumidity);
//           }
//         } else {
//           print("S_RH_SETPT key not found in parsed data");
//         }

//         notifyListeners();
//       } else {
//         print("Data doesn't have proper structure: $data");
//       }
//     } catch (e) {
//       print("Error parsing structured data: $e");
//       print("Data that caused error: $data");
//     }
//   }

//   void sendCompleteStructure() {
//     if (_port == null || !isConnected) {
//       // We'll handle the snackbar in the UI
//       throw Exception("USB not connected");
//     }

//     List<String> pairs = [];

//     pairs.add('SR_WSL:200001');
//     pairs.add('C_PRESSURE_1:000');
//     pairs.add('C_PRESSURE_1_SIGN_BIT:1');
//     pairs.add('C_PRESSURE_2:000');
//     pairs.add('C_PRESSURE_2_SIGN_BIT:1');

//     // Current humidity
//     String humValue = "500"; // default 50.0%
//     if (humidity != "--") {
//       try {
//         double currentHum = double.parse(humidity);
//         humValue = (currentHum * 10).toInt().toString().padLeft(3, '0');
//       } catch (e) {
//         humValue = "500";
//       }
//     }
//     pairs.add('C_RH:$humValue');

//     // Dummy temperature value
//     pairs.add('C_OT_TEMP:250');

//     for (int i = 1; i <= 10; i++) {
//       pairs.add('F_Sensor_${i}_FAULT_BIT:0');
//       pairs.add('S_Sensor_${i}_NO_NC_SETTING:1');
//       pairs.add('S_Light_${i}_ON_OFF:1');
//       pairs.add('S_Light_${i}_Intensity:000');
//     }

//     pairs.add('S_IOT_TIMER:0060');
//     pairs.add(
//       'S_RH_SETPT:${(_pendingHumidity * 10).toInt().toString().padLeft(3, '0')}',
//     );
//     pairs.add('S_TEMP_SETPT:215');

//     String command = '{${pairs.join(',')}}\n';
//     _port!.write(Uint8List.fromList(command.codeUnits));

//     lastSentMessage = command.trim();
//     _saveSetpointHumidity(_pendingHumidity);

//     print("Sent: $command");
//     notifyListeners();
//   }

//   void reconnectUsb() {
//     initUsb();
//   }

//   void requestStatus() {
//     if (_port != null && isConnected) {
//       String command = "STATUS\n";
//       _port!.write(Uint8List.fromList(command.codeUnits));
//       print("Sent STATUS request");
//     }
//   }

//   @override
//   void dispose() {
//     _port?.close();
//     super.dispose();
//   }
// }
