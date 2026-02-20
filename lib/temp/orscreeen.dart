// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
// import 'dart:ui' as ui;
// import 'dart:math';

// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:webview_flutter/webview_flutter.dart';
// import 'package:http/http.dart' as http;
// import 'package:path/path.dart' as path;
// import 'package:permission_handler/permission_handler.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:open_filex/open_filex.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:photo_view/photo_view.dart';
// import 'package:provider/provider.dart';
// import 'package:dio/dio.dart';
// import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_new/return_code.dart';
// import 'package:video_player/video_player.dart';
// import 'package:chewie/chewie.dart';
// import 'package:intl/intl.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:wiespl_contrl_panel/screen/feather/allcctv/rec.dart';

// // ==================== PROVIDER MODELS ====================

// class VideoSwitcherProvider extends ChangeNotifier {
//   // Basic state
//   int _selectedVideoIndex = 0;
//   bool _isConnected = false;
//   bool _isFullScreen = false;
//   String? _usbPath;
//   bool _usbConnected = false;
//   GlobalKey repaintKey = GlobalKey();
//   List<String> _capturedFiles = [];
//   int _selectedStreamIndex = 0;

//   // Recording state
//   bool _isRecording = false;
//   bool _isLoading = true;
//   bool _isConverting = false;
//   String? _recordingPath;
//   CancelToken? _cancelToken;
//   IOSink? _fileSink;
//   int _bytesDownloaded = 0;
//   DateTime? _recordingStartTime;
//   Timer? _uiTimer;
//   double _conversionProgress = 0.0;

//   // Patient related
//   List<Patient> _patientsList = [];
//   bool _isLoadingPatients = false;
//   String _patientError = '';
//   bool _serverOnline = false;
//   String _currentIp = '';

//   // Camera related
//   String _cameraIp = "";
//   List<Map<String, dynamic>> _cctvList = [];

//   // WebView controller
//   late WebViewController _obsController;

//   // Text controllers
//   final TextEditingController messageController = TextEditingController();
//   bool _isSending = false;
//   String? _lastStatus;
//   String? _lastSid;

//   final ApiService apiService = ApiService();

//   // ==================== GETTER METHODS ====================
//   int get selectedVideoIndex => _selectedVideoIndex;
//   bool get isConnected => _isConnected;
//   bool get isFullScreen => _isFullScreen;
//   String? get usbPath => _usbPath;
//   bool get usbConnected => _usbConnected;
//   List<String> get capturedFiles => List.unmodifiable(_capturedFiles);
//   int get selectedStreamIndex => _selectedStreamIndex;
//   bool get isRecording => _isRecording;
//   bool get isLoading => _isLoading;
//   bool get isConverting => _isConverting;
//   String? get recordingPath => _recordingPath;
//   CancelToken? get cancelToken => _cancelToken;
//   IOSink? get fileSink => _fileSink;
//   int get bytesDownloaded => _bytesDownloaded;
//   DateTime? get recordingStartTime => _recordingStartTime;
//   double get conversionProgress => _conversionProgress;
//   List<Patient> get patientsList => List.unmodifiable(_patientsList);
//   bool get isLoadingPatients => _isLoadingPatients;
//   String get patientError => _patientError;
//   bool get serverOnline => _serverOnline;
//   String get currentIp => _currentIp;
//   String get cameraIp => _cameraIp;
//   List<Map<String, dynamic>> get cctvList => List.unmodifiable(_cctvList);
//   WebViewController get obsController => _obsController;
//   bool get isSending => _isSending;
//   String? get lastStatus => _lastStatus;
//   String? get lastSid => _lastSid;

//   // ==================== SETTER METHODS ====================

//   void setSelectedVideoIndex(int index) {
//     _selectedVideoIndex = index;
//     notifyListeners();
//   }

//   void setIsRecording(bool value) {
//     _isRecording = value;
//     notifyListeners();
//   }

//   void setIsLoading(bool value) {
//     _isLoading = value;
//     notifyListeners();
//   }

//   void setIsConverting(bool value) {
//     _isConverting = value;
//     notifyListeners();
//   }

//   void setRecordingPath(String? path) {
//     _recordingPath = path;
//     notifyListeners();
//   }

//   void setCancelToken(CancelToken? token) {
//     _cancelToken = token;
//   }

//   void setFileSink(IOSink? sink) {
//     _fileSink = sink;
//   }

//   void setBytesDownloaded(int bytes) {
//     _bytesDownloaded = bytes;
//     notifyListeners();
//   }

//   void setRecordingStartTime(DateTime? time) {
//     _recordingStartTime = time;
//     notifyListeners();
//   }

//   void setUiTimer(Timer? timer) {
//     _uiTimer?.cancel();
//     _uiTimer = timer;
//   }

//   void setConversionProgress(double progress) {
//     _conversionProgress = progress;
//     notifyListeners();
//   }

//   void setIsConnected(bool value) {
//     _isConnected = value;
//     notifyListeners();
//   }

//   void setIsFullScreen(bool value) {
//     _isFullScreen = value;
//     notifyListeners();
//   }

//   void setUsbPath(String? path) {
//     _usbPath = path;
//     notifyListeners();
//   }

//   void setUsbConnected(bool value) {
//     _usbConnected = value;
//     notifyListeners();
//   }

//   void setSelectedStreamIndex(int index) {
//     _selectedStreamIndex = index;
//     notifyListeners();
//   }

//   void setPatientsList(List<Patient> patients) {
//     _patientsList = patients;
//     notifyListeners();
//   }

//   void setIsLoadingPatients(bool value) {
//     _isLoadingPatients = value;
//     notifyListeners();
//   }

//   void setPatientError(String error) {
//     _patientError = error;
//     notifyListeners();
//   }

//   void setServerOnline(bool value) {
//     _serverOnline = value;
//     notifyListeners();
//   }

//   void setCurrentIp(String ip) {
//     _currentIp = ip;
//     notifyListeners();
//   }

//   void setCameraIp(String ip) {
//     _cameraIp = ip;
//     notifyListeners();
//   }

//   void setCctvList(List<Map<String, dynamic>> list) {
//     _cctvList = list;
//     notifyListeners();
//   }

//   void setObsController(WebViewController controller) {
//     _obsController = controller;
//     notifyListeners();
//   }

//   void setIsSending(bool value) {
//     _isSending = value;
//     notifyListeners();
//   }

//   void setLastStatus(String? status) {
//     _lastStatus = status;
//     notifyListeners();
//   }

//   void setLastSid(String? sid) {
//     _lastSid = sid;
//     notifyListeners();
//   }

//   void addCapturedFile(String filePath) {
//     _capturedFiles.add(filePath);
//     notifyListeners();
//   }

//   void removeCapturedFile(String filePath) {
//     _capturedFiles.remove(filePath);
//     notifyListeners();
//   }

//   void clearCapturedFiles() {
//     _capturedFiles.clear();
//     notifyListeners();
//   }

//   void toggleFullScreen() {
//     _isFullScreen = !_isFullScreen;
//     notifyListeners();
//   }

//   void cancelRecording() {
//     _cancelToken?.cancel("Recording stopped by user");
//     _cancelToken = null;
//   }

//   void closeFileSink() async {
//     try {
//       await _fileSink?.flush();
//       await _fileSink?.close();
//     } catch (e) {
//       print("Error closing file sink: $e");
//     } finally {
//       _fileSink = null;
//     }
//   }

//   void clearRecordingState() {
//     _isRecording = false;
//     _recordingPath = null;
//     _bytesDownloaded = 0;
//     _recordingStartTime = null;
//     _uiTimer?.cancel();
//     _uiTimer = null;
//     notifyListeners();
//   }

//   void disposeResources() {
//     _uiTimer?.cancel();
//     _cancelToken?.cancel();
//     closeFileSink();
//   }
// }

// // ==================== DATA MODELS ====================

// class Patient {
//   final int? id;
//   final String patientId;
//   final String? patientCategory;
//   final String name;
//   final int age;
//   final String gender;
//   final String phone;
//   final String? email;
//   final String? bloodGroup;
//   final String? address;
//   final String? emergencyContact;
//   final String? emergencyName;
//   final String? allergies;
//   final String? medications;
//   final String? medicalHistory;
//   final String? insurance;
//   final String? insuranceId;
//   final String? operationOt;
//   final String? operationDate;
//   final String? operationTime;
//   final String? operationDoctor;
//   final String? operationDoctorRole;
//   final String? operationNotes;
//   final String? createdAt;
//   final int? reportCount;

//   final String? eye;
//   final String? eyeCondition;
//   final String? eyeSurgery;
//   final String? visionLeft;
//   final String? visionRight;
//   final Map<String, dynamic>? checklist;

//   Patient({
//     this.id,
//     required this.patientId,
//     this.patientCategory,
//     required this.name,
//     required this.age,
//     required this.gender,
//     required this.phone,
//     this.email,
//     this.bloodGroup,
//     this.address,
//     this.emergencyContact,
//     this.emergencyName,
//     this.allergies,
//     this.medications,
//     this.medicalHistory,
//     this.insurance,
//     this.insuranceId,
//     this.operationOt,
//     this.operationDate,
//     this.operationTime,
//     this.operationDoctor,
//     this.operationDoctorRole,
//     this.operationNotes,
//     this.createdAt,
//     this.reportCount,
//     this.eye,
//     this.eyeCondition,
//     this.eyeSurgery,
//     this.visionLeft,
//     this.visionRight,
//     this.checklist,
//   });

//   factory Patient.fromJson(Map<String, dynamic> json) {
//     // Handle checklist parsing
//     Map<String, dynamic>? parsedChecklist;
//     if (json['checklist'] != null) {
//       try {
//         if (json['checklist'] is String) {
//           parsedChecklist = jsonDecode(json['checklist']);
//         } else if (json['checklist'] is Map) {
//           parsedChecklist = Map<String, dynamic>.from(json['checklist']);
//         }
//       } catch (e) {
//         print('Error parsing checklist: $e');
//         parsedChecklist = null;
//       }
//     }

//     return Patient(
//       id: json['id'],
//       patientId: json['patient_id'] ?? json['mrd_number'] ?? '',
//       patientCategory: json['patient_category'],
//       name: json['name'] ?? '',
//       age: json['age'] is int
//           ? json['age']
//           : int.tryParse(json['age']?.toString() ?? '0') ?? 0,
//       gender: json['gender'] ?? '',
//       phone: json['phone'] ?? '',
//       email: json['email'],
//       bloodGroup: json['blood_group'],
//       address: json['address'],
//       emergencyContact: json['emergency_contact'],
//       emergencyName: json['emergency_name'],
//       allergies: json['allergies'],
//       medications: json['medications'],
//       medicalHistory: json['medical_history'],
//       insurance: json['insurance'],
//       insuranceId: json['insurance_id'],
//       operationOt: json['operation_ot'],
//       operationDate: json['operation_date'],
//       operationTime: json['operation_time'],
//       operationDoctor: json['operation_doctor'],
//       operationDoctorRole: json['operation_doctor_role'],
//       operationNotes: json['operation_notes'],
//       createdAt: json['created_at'],
//       reportCount: json['report_count'],
//       eye: json['eye'],
//       eyeCondition: json['eye_condition'],
//       eyeSurgery: json['eye_surgery'],
//       visionLeft: json['vision_left'],
//       visionRight: json['vision_right'],
//       checklist: parsedChecklist,
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'patient_id': patientId,
//       'patient_category': patientCategory,
//       'name': name,
//       'age': age,
//       'gender': gender,
//       'phone': phone,
//       'email': email,
//       'blood_group': bloodGroup,
//       'address': address,
//       'emergency_contact': emergencyContact,
//       'emergency_name': emergencyName,
//       'allergies': allergies,
//       'medications': medications,
//       'medical_history': medicalHistory,
//       'insurance': insurance,
//       'insurance_id': insuranceId,
//       'operation_ot': operationOt,
//       'operation_date': operationDate,
//       'operation_time': operationTime,
//       'operation_doctor': operationDoctor,
//       'operation_doctor_role': operationDoctorRole,
//       'operation_notes': operationNotes,
//     };
//   }

//   // Helper method to get formatted checklist data
//   Map<String, dynamic>? get formattedChecklist {
//     if (checklist == null) return null;

//     try {
//       // Check if it's the detailed checklist structure
//       if (checklist!['detailedChecklist'] != null) {
//         return checklist!['detailedChecklist'] as Map<String, dynamic>;
//       }
//       return checklist;
//     } catch (e) {
//       print('Error formatting checklist: $e');
//       return null;
//     }
//   }

//   // Helper method to check if checklist exists
//   bool get hasChecklist {
//     return checklist != null;
//   }

//   // Helper method to get checklist type
//   String? get checklistType {
//     if (checklist == null) return null;

//     final formatted = formattedChecklist;
//     if (formatted != null && formatted['metadata'] != null) {
//       return formatted['metadata']['formType']?.toString();
//     }
//     return null;
//   }

//   // Helper method to get checklist hospital name
//   String? get checklistHospital {
//     if (checklist == null) return null;

//     final formatted = formattedChecklist;
//     if (formatted != null && formatted['metadata'] != null) {
//       return formatted['metadata']['hospitalName']?.toString();
//     }
//     return null;
//   }
// }

// class Report {
//   final int id;
//   final String patientId;
//   final String originalName;
//   final String filename;
//   final int fileSize;
//   final String fileType;
//   final String description;
//   final String fileUrl;
//   final String? uploadDate;

//   Report({
//     required this.id,
//     required this.patientId,
//     required this.originalName,
//     required this.filename,
//     required this.fileSize,
//     required this.fileType,
//     required this.description,
//     required this.fileUrl,
//     this.uploadDate,
//   });

//   factory Report.fromJson(Map<String, dynamic> json) {
//     return Report(
//       id: json['id'] ?? 0,
//       patientId: json['patient_id'] ?? '',
//       originalName: json['original_name'] ?? 'Unknown Report',
//       filename: json['filename'] ?? '',
//       fileSize: json['file_size'] ?? 0,
//       fileType: json['file_type'] ?? 'application/octet-stream',
//       description: json['description'] ?? '',
//       fileUrl: json['file_url'] ?? '',
//       uploadDate: json['upload_date'],
//     );
//   }
// }

// // ==================== API SERVICE ====================

// class ApiService {
//   static String baseUrl = 'http://192.168.0.101:3000/api';

//   static Future<void> initializeBaseUrl() async {
//     final prefs = await SharedPreferences.getInstance();
//     final patientSystemIp = prefs.getString('patientSystemIp');
//     if (patientSystemIp != null && patientSystemIp.isNotEmpty) {
//       baseUrl = 'http://$patientSystemIp:3000/api';
//       print("=== DEBUG: API Base URL set to: $baseUrl ===");
//     } else {
//       print("=== DEBUG: Using default API Base URL: $baseUrl ===");
//     }
//   }

//   void _handleError(http.Response response) {
//     if (response.statusCode >= 400) {
//       final errorData = json.decode(response.body);
//       throw Exception(errorData['error'] ?? 'An error occurred');
//     }
//   }

//   Future<List<Patient>> getPatientsWithReports() async {
//     await initializeBaseUrl();
//     print("=== DEBUG: Calling API: $baseUrl/patients-with-reports ===");

//     try {
//       final response = await http.get(
//         Uri.parse('$baseUrl/patients-with-reports'),
//         headers: {'Accept': 'application/json'},
//       );

//       print("=== DEBUG: Response Status: ${response.statusCode} ===");

//       _handleError(response);

//       final List<dynamic> data = json.decode(response.body);
//       print("=== DEBUG: Parsed ${data.length} total patients from API ===");

//       if (data.isNotEmpty) {
//         print(
//           "=== DEBUG: Sample patient - Name: ${data[0]['name']}, Date: ${data[0]['operation_date']}, OT: ${data[0]['operation_ot']} ===",
//         );
//       }

//       return data.map((json) => Patient.fromJson(json)).toList();
//     } catch (e) {
//       print("=== DEBUG: Error in getPatientsWithReports: $e ===");
//       rethrow;
//     }
//   }

//   Future<List<Patient>> getPatientsByDate(String date) async {
//     await initializeBaseUrl();
//     print("=== DEBUG: Calling getPatientsByDate with date: $date ===");

//     try {
//       final response = await http.get(
//         Uri.parse('$baseUrl/patients-by-date?date=$date'),
//         headers: {'Accept': 'application/json'},
//       );

//       print("=== DEBUG: Date Response Status: ${response.statusCode} ===");

//       if (response.statusCode != 200) {
//         print(
//           "=== DEBUG: Date API failed with status ${response.statusCode}, using fallback ===",
//         );
//         throw Exception('Date-specific API failed');
//       }

//       final List<dynamic> data = json.decode(response.body);
//       print("=== DEBUG: Found ${data.length} patients for date $date ===");

//       return data.map((json) => Patient.fromJson(json)).toList();
//     } catch (e) {
//       print("=== DEBUG: Error in getPatientsByDate: $e ===");
//       rethrow;
//     }
//   }

//   Future<Patient> getPatient(String patientId) async {
//     await initializeBaseUrl();
//     final response = await http.get(Uri.parse('$baseUrl/patients/$patientId'));
//     _handleError(response);
//     final data = json.decode(response.body);
//     return Patient.fromJson(data);
//   }

//   Future<bool> checkServerStatus() async {
//     await initializeBaseUrl();
//     try {
//       print("=== DEBUG: Checking server status at: $baseUrl/test ===");
//       final response = await http.get(
//         Uri.parse('$baseUrl/test'),
//         headers: {'Accept': 'application/json'},
//       );
//       print("=== DEBUG: Server status response: ${response.statusCode} ===");
//       return response.statusCode == 200;
//     } catch (e) {
//       print("=== DEBUG: Server status check failed: $e ===");
//       return false;
//     }
//   }

//   Future<List<Report>> getReports(String patientId) async {
//     await initializeBaseUrl();
//     final response = await http.get(
//       Uri.parse('$baseUrl/patients/$patientId/reports'),
//     );
//     _handleError(response);
//     final List<dynamic> data = json.decode(response.body);
//     return data.map((json) => Report.fromJson(json)).toList();
//   }

//   Future<List<int>> downloadReport(String patientId, int reportId) async {
//     await initializeBaseUrl();
//     final response = await http.get(
//       Uri.parse('$baseUrl/patients/$patientId/reports/$reportId/download'),
//     );
//     _handleError(response);
//     return response.bodyBytes;
//   }
// }

// // ==================== VIDEO PLAYER SCREEN ====================

// class VideoPlayerScreen extends StatefulWidget {
//   final String filePath;
//   final String fileName;

//   const VideoPlayerScreen({
//     Key? key,
//     required this.filePath,
//     required this.fileName,
//   }) : super(key: key);

//   @override
//   State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
// }

// class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
//   late VideoPlayerController _videoController;
//   ChewieController? _chewieController;
//   bool _isInitialized = false;
//   String? _error;
//   bool _isMp4 = true;

//   @override
//   void initState() {
//     super.initState();
//     _initializePlayer();
//   }

//   Future<void> _initializePlayer() async {
//     try {
//       final file = File(widget.filePath);
//       if (!await file.exists()) {
//         throw "File not found at ${widget.filePath}";
//       }

//       _isMp4 = widget.filePath.toLowerCase().endsWith('.mp4');

//       _videoController = VideoPlayerController.file(file);
//       await _videoController.initialize();

//       _chewieController = ChewieController(
//         videoPlayerController: _videoController,
//         autoPlay: true,
//         looping: false,
//         aspectRatio: _videoController.value.aspectRatio,
//         errorBuilder: (context, errorMessage) {
//           return Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.error_outline, color: Colors.red, size: 50),
//                 SizedBox(height: 10),
//                 Text(
//                   "Video Error",
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 SizedBox(height: 5),
//                 Text(
//                   errorMessage,
//                   style: TextStyle(color: Colors.white70),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 20),
//                 if (!_isMp4)
//                   Text(
//                     "Note: This is a raw MJPEG file. Try converting to MP4 first.",
//                     style: TextStyle(color: Colors.orange, fontSize: 12),
//                     textAlign: TextAlign.center,
//                   ),
//               ],
//             ),
//           );
//         },
//         allowedScreenSleep: false,
//         showControls: true,
//         materialProgressColors: ChewieProgressColors(
//           playedColor: Colors.red,
//           handleColor: Colors.red,
//           backgroundColor: Colors.grey,
//           bufferedColor: Colors.grey.withOpacity(0.5),
//         ),
//       );

//       if (mounted) {
//         setState(() => _isInitialized = true);
//       }

//       Future.delayed(Duration(seconds: 3), () {
//         if (mounted && !_videoController.value.isPlaying && _isInitialized) {
//           setState(() {
//             _error = "Video failed to play. May be corrupted or wrong format.";
//           });
//         }
//       });
//     } catch (e) {
//       print("=== DEBUG: Video player error: $e ===");
//       if (mounted) {
//         setState(() => _error = e.toString());
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _videoController.dispose();
//     _chewieController?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: Row(
//           children: [
//             Icon(
//               _isMp4 ? Icons.videocam : Icons.warning_amber,
//               color: _isMp4 ? Colors.white : Colors.orange,
//             ),
//             SizedBox(width: 8),
//             Expanded(
//               child: Text(widget.fileName, overflow: TextOverflow.ellipsis),
//             ),
//             if (!_isMp4)
//               Container(
//                 margin: EdgeInsets.only(left: 8),
//                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: Colors.orange.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(4),
//                   border: Border.all(color: Colors.orange),
//                 ),
//                 child: Text(
//                   "MJPEG",
//                   style: TextStyle(
//                     color: Colors.orange,
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//         backgroundColor: Colors.black,
//         actions: [
//           if (_isMp4)
//             IconButton(
//               icon: Icon(Icons.info_outline),
//               onPressed: () => _showVideoInfo(context),
//             ),
//         ],
//       ),
//       body: _error != null
//           ? Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.error_outline, color: Colors.red, size: 60),
//                   SizedBox(height: 20),
//                   Text(
//                     "Error playing video",
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   SizedBox(height: 10),
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 20),
//                     child: Text(
//                       _error!,
//                       style: TextStyle(color: Colors.white70),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                   SizedBox(height: 20),
//                   ElevatedButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: Text("Go Back"),
//                   ),
//                 ],
//               ),
//             )
//           : _isInitialized
//           ? Chewie(controller: _chewieController!)
//           : Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   CircularProgressIndicator(color: Colors.red),
//                   SizedBox(height: 20),
//                   Text(
//                     "Loading video...",
//                     style: TextStyle(color: Colors.white70),
//                   ),
//                   SizedBox(height: 10),
//                   if (!_isMp4)
//                     Text(
//                       "MJPEG files may take longer to load",
//                       style: TextStyle(color: Colors.orange, fontSize: 12),
//                     ),
//                 ],
//               ),
//             ),
//     );
//   }

//   void _showVideoInfo(BuildContext context) async {
//     try {
//       final file = File(widget.filePath);
//       if (await file.exists()) {
//         final stat = file.statSync();
//         final fileSize = await file.length();

//         showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//             title: Text('Video Information'),
//             content: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text('Name: ${widget.fileName}'),
//                   Text('Format: ${_isMp4 ? "MP4" : "MJPEG"}'),
//                   Text('Size: ${_formatBytes(fileSize)}'),
//                   Text(
//                     'Duration: ${_videoController.value.duration.toString().split('.')[0]}',
//                   ),
//                   Text(
//                     'Resolution: ${_videoController.value.size.width.toInt()}x${_videoController.value.size.height.toInt()}',
//                   ),
//                   Text(
//                     'Aspect Ratio: ${_videoController.value.aspectRatio.toStringAsFixed(2)}',
//                   ),
//                   Text(
//                     'Created: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(stat.changed)}',
//                   ),
//                 ],
//               ),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text('Close'),
//               ),
//             ],
//           ),
//         );
//       }
//     } catch (e) {
//       print("=== DEBUG: Error getting video info: $e ===");
//     }
//   }
// }

// // Helper function for formatting bytes
// String _formatBytes(int bytes) {
//   if (bytes <= 0) return '0 B';
//   const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
//   final i = (bytes > 0 ? (log(bytes) / log(1024)) : 0).floor();
//   return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
// }

// // ==================== HELPER METHODS ====================

// Color _getStatusColor(String? status) {
//   if (status == null) return Colors.grey;
//   switch (status.toLowerCase()) {
//     case 'in surgery':
//       return Colors.red;
//     case 'waiting':
//       return Colors.orange;
//     case 'recovery':
//       return Colors.blue;
//     case 'discharged':
//       return Colors.green;
//     case 'pre-op':
//       return Colors.purple;
//     default:
//       return Colors.grey;
//   }
// }

// String _getStatusText(Patient patient) {
//   if (patient.operationDate != null) {
//     final now = DateTime.now();
//     final opDate = DateTime.tryParse(patient.operationDate ?? '');
//     if (opDate != null && opDate.isAfter(now)) return 'Scheduled';
//     if (opDate != null && opDate.isBefore(now)) return 'Completed';
//   }
//   return patient.patientCategory ?? 'General';
// }

// String _getTodayDate() {
//   final now = DateTime.now();
//   return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
// }

// // ==================== CHECKLIST DISPLAY METHODS ====================

// Widget _buildChecklistItem(String label, dynamic value, {Color? color}) {
//   String displayValue = '';

//   if (value == null || value == '') {
//     displayValue = 'Not specified';
//   } else if (value is List) {
//     displayValue = value.isEmpty ? 'None' : value.join(', ');
//   } else if (value is Map) {
//     displayValue = '${value.length} items';
//   } else {
//     displayValue = value.toString();
//   }

//   return Padding(
//     padding: const EdgeInsets.symmetric(vertical: 4),
//     child: Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(
//           width: 120,
//           child: Text(
//             '$label:',
//             style: TextStyle(
//               color: Colors.white70,
//               fontSize: 12,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ),
//         SizedBox(width: 8),
//         Expanded(
//           child: Text(
//             displayValue,
//             style: TextStyle(color: color ?? Colors.white, fontSize: 12),
//           ),
//         ),
//       ],
//     ),
//   );
// }

// Widget _buildChecklistSection(String title, List<Widget> children) {
//   return Container(
//     margin: const EdgeInsets.only(top: 12),
//     padding: const EdgeInsets.all(12),
//     decoration: BoxDecoration(
//       color: Colors.blue.withOpacity(0.1),
//       borderRadius: BorderRadius.circular(8),
//       border: Border.all(color: Colors.blue.withOpacity(0.3)),
//     ),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(Icons.checklist, size: 16, color: Colors.blueAccent),
//             SizedBox(width: 8),
//             Text(
//               title,
//               style: TextStyle(
//                 color: Colors.blueAccent,
//                 fontSize: 14,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//         SizedBox(height: 8),
//         ...children,
//       ],
//     ),
//   );
// }

// List<Widget> _buildChecklistWidgets(Map<String, dynamic> checklistData) {
//   final List<Widget> widgets = [];

//   // Metadata section
//   if (checklistData['metadata'] != null) {
//     final metadata = checklistData['metadata'] as Map<String, dynamic>;
//     widgets.addAll([
//       _buildChecklistSection('Checklist Information', [
//         _buildChecklistItem('Form Type', metadata['formType']),
//         _buildChecklistItem('Hospital', metadata['hospitalName']),
//         _buildChecklistItem('Completed By', metadata['completedBy']),
//         _buildChecklistItem(
//           'Collection Date',
//           metadata['collectedAt']?.toString().split('T')[0],
//         ),
//       ]),
//     ]);
//   }

//   // Patient Info
//   if (checklistData['patientInfo'] != null) {
//     final patientInfo = checklistData['patientInfo'] as Map<String, dynamic>;
//     widgets.addAll([
//       _buildChecklistSection('Patient Information', [
//         _buildChecklistItem('Patient Name', patientInfo['patientName']),
//         _buildChecklistItem('MRD Number', patientInfo['mrdNumber']),
//         _buildChecklistItem('Age', patientInfo['age']),
//         _buildChecklistItem('Gender', patientInfo['gender']),
//         _buildChecklistItem('Phone', patientInfo['phone']),
//         _buildChecklistItem('Lab Name', patientInfo['labName']),
//         _buildChecklistItem('Physician', patientInfo['physician']),
//         _buildChecklistItem('Physician Date', patientInfo['physicianDate']),
//       ]),
//     ]);
//   }

//   // Medical History
//   if (checklistData['medicalHistory'] != null) {
//     final medicalHistory =
//         checklistData['medicalHistory'] as Map<String, dynamic>;
//     widgets.addAll([
//       _buildChecklistSection('Medical History', [
//         _buildChecklistItem('Diabetic', medicalHistory['diabetic']),
//         _buildChecklistItem('Diabetic Since', medicalHistory['diabeticSince']),
//         _buildChecklistItem('Insulin', medicalHistory['insulin']),
//         _buildChecklistItem('Cardiac Issues', medicalHistory['cardiac']),
//         _buildChecklistItem('Angioplasty', medicalHistory['angioplasty']),
//         _buildChecklistItem('Bypass Surgery', medicalHistory['bypass']),
//         _buildChecklistItem('Blood Thinners', medicalHistory['bloodThinner']),
//         _buildChecklistItem('Kidney Issues', medicalHistory['kidney']),
//         _buildChecklistItem('Dialysis', medicalHistory['dialysis']),
//         _buildChecklistItem('Other', medicalHistory['other']),
//       ]),
//     ]);
//   }

//   // Blood Tests
//   if (checklistData['bloodTests'] != null) {
//     final bloodTests = checklistData['bloodTests'] as Map<String, dynamic>;
//     final bloodTestWidgets = <Widget>[
//       _buildChecklistItem('Hemoglobin', bloodTests['hemoglobin']),
//       _buildChecklistItem('ESR', bloodTests['esr']),
//       _buildChecklistItem('CRP', bloodTests['crp']),
//       _buildChecklistItem('Platelet', bloodTests['platelet']),
//       _buildChecklistItem('TLC', bloodTests['tlc']),
//     ];

//     // DLC (Differential Count)
//     if (bloodTests['dlc'] != null) {
//       final dlc = bloodTests['dlc'] as Map<String, dynamic>;
//       bloodTestWidgets.addAll([
//         SizedBox(height: 8),
//         Text(
//           'Differential Count:',
//           style: TextStyle(color: Colors.white70, fontSize: 12),
//         ),
//         _buildChecklistItem('  Neutrophil', dlc['neutrophil']),
//         _buildChecklistItem('  Lymphocyte', dlc['lymphocyte']),
//         _buildChecklistItem('  Eosinophil', dlc['eosinophil']),
//         _buildChecklistItem('  Monocyte', dlc['monocyte']),
//         _buildChecklistItem('  Basophil', dlc['basophil']),
//       ]);
//     }

//     // Blood Sugar
//     if (bloodTests['bloodSugar'] != null) {
//       final bloodSugar = bloodTests['bloodSugar'] as Map<String, dynamic>;
//       bloodTestWidgets.addAll([
//         SizedBox(height: 8),
//         Text(
//           'Blood Sugar:',
//           style: TextStyle(color: Colors.white70, fontSize: 12),
//         ),
//         _buildChecklistItem('  FBS', bloodSugar['fbs']),
//         _buildChecklistItem('  PPBS', bloodSugar['ppbs']),
//         _buildChecklistItem('  RBS', bloodSugar['rbs']),
//         _buildChecklistItem('  HbA1c', bloodSugar['hba1c']),
//       ]);
//     }

//     // Biochemistry
//     if (bloodTests['biochemistry'] != null) {
//       final biochemistry = bloodTests['biochemistry'] as Map<String, dynamic>;
//       bloodTestWidgets.addAll([
//         SizedBox(height: 8),
//         Text(
//           'Biochemistry:',
//           style: TextStyle(color: Colors.white70, fontSize: 12),
//         ),
//         _buildChecklistItem('  Creatinine', biochemistry['creatinine']),
//         _buildChecklistItem('  BUN', biochemistry['bun']),
//         _buildChecklistItem('  Sodium', biochemistry['sodium']),
//         _buildChecklistItem('  Potassium', biochemistry['potassium']),
//         _buildChecklistItem('  Chloride', biochemistry['chloride']),
//       ]);
//     }

//     widgets.add(_buildChecklistSection('Blood Tests', bloodTestWidgets));
//   }

//   // Urine Tests
//   if (checklistData['urineTests'] != null) {
//     final urineTests = checklistData['urineTests'] as Map<String, dynamic>;
//     widgets.addAll([
//       _buildChecklistSection('Urine Tests', [
//         _buildChecklistItem('Protein', urineTests['protein']),
//         _buildChecklistItem('Glucose', urineTests['glucose']),
//         _buildChecklistItem('Ketone', urineTests['ketone']),
//         _buildChecklistItem('Blood', urineTests['blood']),
//         _buildChecklistItem('Pus Cells', urineTests['pusCells']),
//         _buildChecklistItem('Epithelial Cells', urineTests['epithelialCells']),
//         _buildChecklistItem('Bacteria', urineTests['bacteria']),
//         _buildChecklistItem('Cast', urineTests['cast']),
//       ]),
//     ]);
//   }

//   // Infective Profile
//   if (checklistData['infectiveProfile'] != null) {
//     final infectiveProfile =
//         checklistData['infectiveProfile'] as Map<String, dynamic>;
//     widgets.addAll([
//       _buildChecklistSection('Infective Profile', [
//         _buildChecklistItem('HBsAg', infectiveProfile['hbsag']),
//         _buildChecklistItem('HIV', infectiveProfile['hiv']),
//         _buildChecklistItem('HCV', infectiveProfile['hcv']),
//         _buildChecklistItem('HBV', infectiveProfile['hbv']),
//       ]),
//     ]);
//   }

//   // Verification
//   if (checklistData['verification'] != null) {
//     final verification = checklistData['verification'] as Map<String, dynamic>;
//     widgets.addAll([
//       _buildChecklistSection('Verification', [
//         _buildChecklistItem('Nurse Verified', verification['nurseVerified']),
//         _buildChecklistItem('Nurse Time', verification['nurseTime']),
//         _buildChecklistItem('Doctor Verified', verification['doctorVerified']),
//         _buildChecklistItem('Doctor Time', verification['doctorTime']),
//       ]),
//     ]);
//   }

//   return widgets;
// }

// // ==================== MAIN VIDEO SWITCHER SCREEN ====================

// class VideoSwitcherScreen extends StatefulWidget {
//   const VideoSwitcherScreen({super.key});

//   @override
//   State<VideoSwitcherScreen> createState() => _VideoSwitcherScreenState();
// }

// class _VideoSwitcherScreenState extends State<VideoSwitcherScreen> {
//   final String baseUrl = 'http://192.168.0.43:5000';
//   late VideoSwitcherProvider _provider;
//   String otNumber = ""; // OT number variable

//   @override
//   void initState() {
//     super.initState();
//     _provider = Provider.of<VideoSwitcherProvider>(context, listen: false);
//     _initializeApp();
//   }

//   Future<void> _initializeApp() async {
//     try {
//       print("=== DEBUG: Starting app initialization ===");

//       // Load OT number first
//       await lodeotno();
//       print("=== DEBUG: OT Number loaded: $otNumber ===");

//       await _loadUSBPath(_provider);
//       print("=== DEBUG: USB Path loaded: ${_provider.usbPath} ===");

//       await _requestPermissions();
//       print("=== DEBUG: Permissions requested ===");

//       await loadCameraIp(_provider);
//       print("=== DEBUG: Camera IP loaded: ${_provider.cameraIp} ===");

//       checkConnection(_provider);
//       print("=== DEBUG: Connection checked ===");

//       await _loadPatients(_provider);
//       print("=== DEBUG: Patients loaded: ${_provider.patientsList.length} ===");

//       print("=== DEBUG: App initialization complete ===");
//     } catch (e) {
//       print("=== DEBUG: Error during initialization: $e ===");
//     }
//   }

//   Future<void> lodeotno() async {
//     final prefs = await SharedPreferences.getInstance();
//     otNumber = prefs.getString('otNumber') ?? "dddddd";
//     print("=== DEBUG: Loaded OT Number from SharedPreferences: $otNumber ===");
//   }

//   Future<void> loadCameraIp(VideoSwitcherProvider provider) async {
//     final prefs = await SharedPreferences.getInstance();
//     final cameraIp = prefs.getString('cameraIp') ?? "192.168.1.115";

//     provider.setCameraIp(cameraIp);

//     final cctvList = [
//       {'name': 'SOURCE 1', 'controller': null, 'url': 'http://$cameraIp:9081'},
//     ];

//     provider.setCctvList(cctvList);
//     _initializeWebViewControllers(provider);
//   }

//   void _initializeWebViewControllers(VideoSwitcherProvider provider) {
//     final controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..setBackgroundColor(const Color(0x00000000))
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onProgress: (int progress) {
//             print('WebView loading: $progress%');
//           },
//           onPageStarted: (String url) {
//             print('Page started loading: $url');
//           },
//           onPageFinished: (String url) {
//             print('Page finished loading: $url');
//           },
//           onWebResourceError: (WebResourceError error) {
//             print('WebView error: ${error.description}');
//           },
//           onNavigationRequest: (NavigationRequest request) {
//             return NavigationDecision.navigate;
//           },
//         ),
//       )
//       ..loadRequest(Uri.parse('http://${provider.cameraIp}:9081'));

//     provider.setObsController(controller);

//     final updatedCctvList = List<Map<String, dynamic>>.from(provider.cctvList);
//     if (updatedCctvList.isNotEmpty) {
//       updatedCctvList[0]['controller'] = controller;
//       provider.setCctvList(updatedCctvList);
//     }

//     provider.setIsLoading(false);
//   }

//   Future<void> _loadUSBPath(VideoSwitcherProvider provider) async {
//     try {
//       print("=== DEBUG: Loading USB path from SharedPreferences ===");
//       final prefs = await SharedPreferences.getInstance();
//       final savedPath = prefs.getString("usbPath");

//       if (savedPath != null && savedPath.isNotEmpty) {
//         print("=== DEBUG: Found saved path: $savedPath ===");

//         final directory = Directory(savedPath);
//         if (await directory.exists()) {
//           provider.setUsbPath(savedPath);
//           provider.setUsbConnected(true);
//           print("=== DEBUG: USB path loaded successfully ===");
//         } else {
//           print("=== DEBUG: Saved directory doesn't exist ===");
//           try {
//             await directory.create(recursive: true);
//             provider.setUsbPath(savedPath);
//             provider.setUsbConnected(true);
//             print("=== DEBUG: Directory created successfully ===");
//           } catch (e) {
//             print("=== DEBUG: Failed to create directory: $e ===");
//             await prefs.remove("usbPath");
//             provider.setUsbPath(null);
//             provider.setUsbConnected(false);
//           }
//         }
//       } else {
//         print("=== DEBUG: No saved USB path found ===");
//         provider.setUsbPath(null);
//         provider.setUsbConnected(false);
//       }
//     } catch (e) {
//       print("=== DEBUG: Error loading USB path: $e ===");
//       provider.setUsbPath(null);
//       provider.setUsbConnected(false);
//     }
//   }

//   Future<void> _loadPatients(VideoSwitcherProvider provider) async {
//     provider.setIsLoadingPatients(true);
//     provider.setPatientError('');

//     try {
//       await _loadCurrentIp(provider);
//       await _checkServerStatus(provider);

//       final todayDate = _getTodayDate();

//       print("=== DEBUG: Loading patients for today: $todayDate ===");
//       print("=== DEBUG: Filtering by OT: $otNumber ===");

//       if (provider.serverOnline) {
//         print("=== DEBUG: Server is online ===");

//         List<Patient> filteredPatients = [];

//         try {
//           print("=== DEBUG: Attempting date-specific API call ===");
//           final datePatients = await provider.apiService.getPatientsByDate(
//             todayDate,
//           );

//           // Filter patients by OT number
//           filteredPatients = datePatients.where((patient) {
//             final patientOt = patient.operationOt ?? '';
//             final matchesOt = patientOt == otNumber;
//             print(
//               "=== DEBUG: Filter check - ${patient.name}: OT match: $matchesOt (${patient.operationOt} vs $otNumber) ===",
//             );
//             return matchesOt;
//           }).toList();

//           print(
//             "=== DEBUG: Found ${filteredPatients.length} patients for today in OT $otNumber ===",
//           );
//         } catch (dateError) {
//           print("=== DEBUG: Date API failed, using fallback: $dateError ===");

//           final allPatients = await provider.apiService
//               .getPatientsWithReports();
//           print(
//             "=== DEBUG: Total patients from API: ${allPatients.length} ===",
//           );

//           filteredPatients = allPatients.where((patient) {
//             if (patient.operationDate == null) {
//               print(
//                 "=== DEBUG: Patient ${patient.name} has no operation date ===",
//               );
//               return false;
//             }

//             final matchesDate = patient.operationDate!.startsWith(todayDate);
//             final patientOt = patient.operationOt ?? '';
//             final matchesOt = patientOt == otNumber;

//             print(
//               "=== DEBUG: Filter check - ${patient.name}: "
//               "Date match: $matchesDate (${patient.operationDate} vs $todayDate), "
//               "OT match: $matchesOt (${patient.operationOt} vs $otNumber) ===",
//             );

//             return matchesDate && matchesOt;
//           }).toList();

//           print(
//             "=== DEBUG: Fallback found ${filteredPatients.length} patients for today in OT $otNumber ===",
//           );
//         }

//         filteredPatients.sort((a, b) {
//           final timeA = a.operationTime ?? '';
//           final timeB = b.operationTime ?? '';
//           return timeA.compareTo(timeB);
//         });

//         provider.setPatientsList(filteredPatients);

//         if (filteredPatients.isEmpty) {
//           final errorMsg =
//               'No patients found for today ($todayDate) in $otNumber';
//           print("=== DEBUG: $errorMsg ===");
//           provider.setPatientError(errorMsg);
//         } else {
//           print(
//             "=== DEBUG: Successfully loaded ${filteredPatients.length} patients for OT $otNumber ===",
//           );
//         }
//       } else {
//         provider.setPatientError('Server offline. Cannot load patients.');
//         provider.setPatientsList([]);
//         print("=== DEBUG: Server is offline ===");
//       }

//       provider.setIsLoadingPatients(false);
//     } catch (e) {
//       print("=== DEBUG: Error in _loadPatients: $e ===");
//       print("=== DEBUG: Stack trace: ${e.toString()} ===");
//       provider.setPatientError('Failed to load patients: ${e.toString()}');
//       provider.setIsLoadingPatients(false);
//       provider.setPatientsList([]);
//     }
//   }

//   Future<void> _loadCurrentIp(VideoSwitcherProvider provider) async {
//     final prefs = await SharedPreferences.getInstance();
//     final patientSystemIp = prefs.getString('patientSystemIp');
//     provider.setCurrentIp(patientSystemIp ?? 'Not configured');
//   }

//   Future<void> _checkServerStatus(VideoSwitcherProvider provider) async {
//     final isOnline = await provider.apiService.checkServerStatus();
//     provider.setServerOnline(isOnline);
//   }

//   Widget _buildPatientCard(BuildContext context, Patient patient, int index) {
//     final statusColor = _getStatusColor(patient.operationOt);
//     final statusText = _getStatusText(patient);

//     // Check if patient has checklist
//     bool hasChecklist = patient.hasChecklist;

//     String timeStatus = '';
//     Color timeColor = Colors.white70;
//     if (patient.operationTime != null) {
//       final now = DateTime.now();
//       final timeParts = patient.operationTime!.split(':');
//       if (timeParts.length >= 2) {
//         final hour = int.tryParse(timeParts[0]) ?? 0;
//         final minute = int.tryParse(timeParts[1]) ?? 0;
//         final patientTime = DateTime(
//           now.year,
//           now.month,
//           now.day,
//           hour,
//           minute,
//         );

//         if (patientTime.isBefore(now.subtract(Duration(minutes: 30)))) {
//           timeStatus = 'Completed';
//           timeColor = Colors.green;
//         } else if (patientTime.isBefore(now)) {
//           timeStatus = 'In Progress';
//           timeColor = Colors.orange;
//         } else if (patientTime.isBefore(now.add(Duration(minutes: 30)))) {
//           timeStatus = 'Upcoming';
//           timeColor = Colors.blue;
//         } else {
//           timeStatus = 'Scheduled';
//           timeColor = Colors.white70;
//         }
//       }
//     }

//     return Card(
//       margin: const EdgeInsets.only(bottom: 8),
//       color: Colors.white.withOpacity(0.1),
//       child: InkWell(
//         onTap: () => _showPatientDetails(context, patient),
//         borderRadius: BorderRadius.circular(8),
//         child: Padding(
//           padding: const EdgeInsets.all(12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Expanded(
//                     child: Row(
//                       children: [
//                         Text(
//                           patient.name,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         SizedBox(width: 6),
//                         // Checklist indicator
//                         if (hasChecklist)
//                           Container(
//                             padding: EdgeInsets.all(2),
//                             decoration: BoxDecoration(
//                               color: Colors.green,
//                               shape: BoxShape.circle,
//                             ),
//                             child: Icon(
//                               Icons.check,
//                               size: 10,
//                               color: Colors.white,
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 4,
//                     ),
//                     decoration: BoxDecoration(
//                       color: timeColor.withOpacity(0.2),
//                       borderRadius: BorderRadius.circular(4),
//                       border: Border.all(color: timeColor, width: 1),
//                     ),
//                     child: Text(
//                       timeStatus,
//                       style: TextStyle(
//                         color: timeColor,
//                         fontSize: 11,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 6),
//               Row(
//                 children: [
//                   Icon(Icons.person_outline, size: 14, color: Colors.white70),
//                   const SizedBox(width: 6),
//                   Text(
//                     "MRD: ${patient.patientId}",
//                     style: const TextStyle(color: Colors.white70, fontSize: 12),
//                   ),
//                   const Spacer(),
//                   // Show OT number with different color if it matches current OT
//                   if (patient.operationOt != null)
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 6,
//                         vertical: 2,
//                       ),
//                       decoration: BoxDecoration(
//                         color: patient.operationOt == otNumber
//                             ? Colors.green.withOpacity(0.2)
//                             : Colors.blue.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(4),
//                         border: Border.all(
//                           color: patient.operationOt == otNumber
//                               ? Colors.green
//                               : Colors.blue,
//                         ),
//                       ),
//                       child: Text(
//                         patient.operationOt!,
//                         style: TextStyle(
//                           color: patient.operationOt == otNumber
//                               ? Colors.green
//                               : Colors.blueAccent,
//                           fontSize: 10,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//               const SizedBox(height: 4),
//               // Show current OT indicator
//               if (patient.operationOt == otNumber)
//                 Container(
//                   margin: EdgeInsets.only(bottom: 4),
//                   padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: Colors.green.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(Icons.meeting_room, size: 10, color: Colors.green),
//                       SizedBox(width: 4),
//                       Text(
//                         'Current OT',
//                         style: TextStyle(
//                           color: Colors.green,
//                           fontSize: 10,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               const SizedBox(height: 4),
//               Row(
//                 children: [
//                   Icon(Icons.calendar_today, size: 14, color: Colors.white70),
//                   const SizedBox(width: 6),
//                   Text(
//                     "${patient.age} years, ${patient.gender}",
//                     style: const TextStyle(color: Colors.white70, fontSize: 12),
//                   ),
//                   const Spacer(),
//                   if (patient.operationTime != null)
//                     Row(
//                       children: [
//                         Icon(Icons.access_time, size: 14, color: Colors.yellow),
//                         const SizedBox(width: 4),
//                         Text(
//                           patient.operationTime!,
//                           style: const TextStyle(
//                             color: Colors.yellow,
//                             fontSize: 12,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ],
//                     ),
//                 ],
//               ),
//               const SizedBox(height: 4),
//               Row(
//                 children: [
//                   Icon(Icons.phone, size: 14, color: Colors.white70),
//                   const SizedBox(width: 6),
//                   Expanded(
//                     child: Text(
//                       patient.phone,
//                       style: const TextStyle(
//                         color: Colors.white70,
//                         fontSize: 12,
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 ],
//               ),
//               if (patient.operationDoctor != null) ...[
//                 const SizedBox(height: 4),
//                 Row(
//                   children: [
//                     Icon(
//                       Icons.medical_services,
//                       size: 14,
//                       color: Colors.white70,
//                     ),
//                     const SizedBox(width: 6),
//                     Expanded(
//                       child: Text(
//                         "Dr. ${patient.operationDoctor}",
//                         style: const TextStyle(
//                           color: Colors.white70,
//                           fontSize: 12,
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//               if (patient.reportCount != null && patient.reportCount! > 0) ...[
//                 const SizedBox(height: 4),
//                 Row(
//                   children: [
//                     Icon(Icons.folder, size: 14, color: Colors.blueAccent),
//                     const SizedBox(width: 6),
//                     Text(
//                       "${patient.reportCount} reports",
//                       style: const TextStyle(
//                         color: Colors.blueAccent,
//                         fontSize: 12,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//               // Show checklist type if available
//               if (hasChecklist && patient.checklistType != null) ...[
//                 const SizedBox(height: 4),
//                 Row(
//                   children: [
//                     Icon(Icons.checklist, size: 14, color: Colors.green),
//                     const SizedBox(width: 6),
//                     Text(
//                       patient.checklistType!,
//                       style: const TextStyle(
//                         color: Colors.green,
//                         fontSize: 11,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _showPatientDetails(BuildContext context, Patient patient) {
//     // Check if patient has checklist
//     bool hasChecklist = patient.hasChecklist;
//     String checklistType = patient.checklistType ?? 'No Checklist';
//     String? hospitalName = patient.checklistHospital;

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: const Color(0xFF3D8A8F),
//         title: Row(
//           children: [
//             CircleAvatar(
//               backgroundColor: Colors.white,
//               child: Text(
//                 patient.name[0].toUpperCase(),
//                 style: const TextStyle(color: Color(0xFF3D8A8F)),
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     patient.name,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   if (patient.operationOt != null)
//                     Text(
//                       "OT: ${patient.operationOt}",
//                       style: const TextStyle(
//                         color: Colors.white70,
//                         fontSize: 12,
//                       ),
//                     ),
//                   // Show current OT indicator
//                   if (patient.operationOt == otNumber)
//                     Container(
//                       margin: EdgeInsets.only(top: 4),
//                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                       decoration: BoxDecoration(
//                         color: Colors.green.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(4),
//                         border: Border.all(color: Colors.green),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(
//                             Icons.meeting_room,
//                             size: 10,
//                             color: Colors.green,
//                           ),
//                           SizedBox(width: 4),
//                           Text(
//                             'Current OT',
//                             style: TextStyle(
//                               color: Colors.green,
//                               fontSize: 10,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   // Show checklist indicator
//                   if (hasChecklist)
//                     Container(
//                       margin: EdgeInsets.only(top: 4),
//                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                       decoration: BoxDecoration(
//                         color: Colors.green.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(4),
//                         border: Border.all(color: Colors.green),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(Icons.checklist, size: 10, color: Colors.green),
//                           SizedBox(width: 4),
//                           Text(
//                             'Medical Checklist Available',
//                             style: TextStyle(
//                               color: Colors.green,
//                               fontSize: 10,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               _buildDetailRow("Patient MRD:", patient.patientId),
//               _buildDetailRow("Name:", patient.name),
//               _buildDetailRow("Age:", "${patient.age} years"),
//               _buildDetailRow("Gender:", patient.gender),
//               _buildDetailRow("Phone:", patient.phone),
//               if (patient.email != null)
//                 _buildDetailRow("Email:", patient.email!),
//               if (patient.bloodGroup != null)
//                 _buildDetailRow("Blood Group:", patient.bloodGroup!),
//               if (patient.address != null)
//                 _buildDetailRow("Address:", patient.address!),
//               if (patient.operationOt != null)
//                 _buildDetailRow("OT Number:", patient.operationOt!),
//               if (patient.operationDoctor != null)
//                 _buildDetailRow("Doctor:", patient.operationDoctor!),
//               if (patient.operationDate != null)
//                 _buildDetailRow("Operation Date:", patient.operationDate!),
//               if (patient.operationTime != null)
//                 _buildDetailRow("Operation Time:", patient.operationTime!),

//               // Eye Information
//               if (patient.eye != null || patient.eyeCondition != null)
//                 Container(
//                   margin: EdgeInsets.only(top: 8),
//                   padding: EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Colors.blue.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Eye Information:',
//                         style: TextStyle(
//                           color: Colors.blueAccent,
//                           fontSize: 14,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       if (patient.eye != null)
//                         _buildDetailRow("  Eye:", patient.eye!),
//                       if (patient.eyeCondition != null)
//                         _buildDetailRow("  Condition:", patient.eyeCondition!),
//                       if (patient.eyeSurgery != null)
//                         _buildDetailRow("  Surgery:", patient.eyeSurgery!),
//                       if (patient.visionLeft != null)
//                         _buildDetailRow("  Vision Left:", patient.visionLeft!),
//                       if (patient.visionRight != null)
//                         _buildDetailRow(
//                           "  Vision Right:",
//                           patient.visionRight!,
//                         ),
//                     ],
//                   ),
//                 ),

//               if (patient.reportCount != null)
//                 _buildDetailRow(
//                   "Medical Reports:",
//                   "${patient.reportCount} files",
//                   color: Colors.green,
//                 ),

//               // Checklist summary
//               if (hasChecklist)
//                 Container(
//                   margin: EdgeInsets.only(top: 12),
//                   padding: EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.green.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: Colors.green.withOpacity(0.3)),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Icon(
//                             Icons.medical_services,
//                             size: 16,
//                             color: Colors.green,
//                           ),
//                           SizedBox(width: 8),
//                           Text(
//                             'Medical Checklist',
//                             style: TextStyle(
//                               color: Colors.green,
//                               fontSize: 14,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                       SizedBox(height: 6),
//                       _buildDetailRow("Type:", checklistType),
//                       if (hospitalName != null && hospitalName.isNotEmpty)
//                         _buildDetailRow("Hospital:", hospitalName),
//                       SizedBox(height: 8),
//                       ElevatedButton(
//                         onPressed: () {
//                           Navigator.pop(context); // Close current dialog
//                           _showChecklistDetails(context, patient);
//                         },
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.green,
//                           foregroundColor: Colors.white,
//                           minimumSize: Size(double.infinity, 36),
//                         ),
//                         child: Text('View Complete Checklist'),
//                       ),
//                     ],
//                   ),
//                 ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text("Close", style: TextStyle(color: Colors.white)),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _navigateToFullPatientDetails(context, patient);
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
//             child: const Text("View Full Details"),
//           ),
//           if (hasChecklist)
//             ElevatedButton.icon(
//               onPressed: () {
//                 Navigator.pop(context);
//                 _showChecklistDetails(context, patient);
//               },
//               icon: Icon(Icons.checklist, size: 18),
//               label: Text("Checklist"),
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDetailRow(String label, String value, {Color? color}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 100,
//             child: Text(
//               label,
//               style: const TextStyle(
//                 fontWeight: FontWeight.w600,
//                 color: Colors.white70,
//                 fontSize: 14,
//               ),
//             ),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Text(
//               value,
//               style: TextStyle(
//                 fontSize: 14,
//                 color: color ?? Colors.white,
//                 fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showChecklistDetails(BuildContext context, Patient patient) {
//     if (patient.checklist == null || patient.formattedChecklist == null) {
//       Fluttertoast.showToast(
//         msg: "No checklist data available",
//         gravity: ToastGravity.BOTTOM,
//       );
//       return;
//     }

//     final checklistData = patient.formattedChecklist!;

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: const Color(0xFF3D8A8F),
//         title: Row(
//           children: [
//             Icon(Icons.medical_services, color: Colors.white),
//             SizedBox(width: 8),
//             Text(
//               'Medical Checklist',
//               style: TextStyle(color: Colors.white, fontSize: 18),
//             ),
//           ],
//         ),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: _buildChecklistWidgets(checklistData),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close', style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }

//   void _navigateToFullPatientDetails(BuildContext context, Patient patient) {
//     // Check if patient has checklist
//     bool hasChecklist = patient.hasChecklist;

//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         backgroundColor: const Color(0xFF3D8A8F),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         child: SingleChildScrollView(
//           child: Padding(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Center(
//                   child: Column(
//                     children: [
//                       CircleAvatar(
//                         radius: 40,
//                         backgroundColor: Colors.white,
//                         child: Text(
//                           patient.name[0].toUpperCase(),
//                           style: const TextStyle(
//                             fontSize: 32,
//                             fontWeight: FontWeight.bold,
//                             color: Color(0xFF3D8A8F),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       if (patient.operationOt != null)
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 12,
//                             vertical: 4,
//                           ),
//                           decoration: BoxDecoration(
//                             color: Colors.blue.withOpacity(0.2),
//                             borderRadius: BorderRadius.circular(20),
//                             border: Border.all(color: Colors.blue),
//                           ),
//                           child: Text(
//                             "OT: ${patient.operationOt}",
//                             style: const TextStyle(
//                               color: Colors.blueAccent,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 Center(
//                   child: Text(
//                     patient.name,
//                     style: const TextStyle(
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//                 Center(
//                   child: Text(
//                     "MRD: ${patient.patientId}",
//                     style: const TextStyle(color: Colors.white70, fontSize: 14),
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 const Divider(color: Colors.white38),
//                 const SizedBox(height: 10),

//                 if (patient.operationDate != null ||
//                     patient.operationTime != null)
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         "Operation Schedule",
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.white,
//                         ),
//                       ),
//                       const SizedBox(height: 10),
//                       if (patient.operationDate != null)
//                         _buildFullDetailRow("Date", patient.operationDate!),
//                       if (patient.operationTime != null)
//                         _buildFullDetailRow("Time", patient.operationTime!),
//                       if (patient.operationOt != null)
//                         _buildFullDetailRow("OT Room", patient.operationOt!),
//                       if (patient.operationDoctor != null)
//                         _buildFullDetailRow("Doctor", patient.operationDoctor!),
//                       const SizedBox(height: 20),
//                       const Divider(color: Colors.white38),
//                     ],
//                   ),

//                 const Text(
//                   "Personal Information",
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 _buildFullDetailRow("Age", "${patient.age} years"),
//                 _buildFullDetailRow("Gender", patient.gender),
//                 _buildFullDetailRow("Phone", patient.phone),
//                 if (patient.email != null)
//                   _buildFullDetailRow("Email", patient.email!),
//                 if (patient.bloodGroup != null)
//                   _buildFullDetailRow("Blood Group", patient.bloodGroup!),
//                 if (patient.address != null)
//                   _buildFullDetailRow("Address", patient.address!),

//                 // Eye Information
//                 if (patient.eye != null || patient.eyeCondition != null) ...[
//                   const SizedBox(height: 20),
//                   const Divider(color: Colors.white38),
//                   const SizedBox(height: 10),
//                   const Text(
//                     "Eye Information",
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   if (patient.eye != null)
//                     _buildFullDetailRow("Eye", patient.eye!),
//                   if (patient.eyeCondition != null)
//                     _buildFullDetailRow("Condition", patient.eyeCondition!),
//                   if (patient.eyeSurgery != null)
//                     _buildFullDetailRow("Surgery History", patient.eyeSurgery!),
//                   if (patient.visionLeft != null)
//                     _buildFullDetailRow("Vision (Left)", patient.visionLeft!),
//                   if (patient.visionRight != null)
//                     _buildFullDetailRow("Vision (Right)", patient.visionRight!),
//                 ],

//                 if (patient.allergies != null ||
//                     patient.medications != null) ...[
//                   const SizedBox(height: 20),
//                   const Divider(color: Colors.white38),
//                   const SizedBox(height: 10),
//                   const Text(
//                     "Medical Information",
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   if (patient.allergies != null)
//                     _buildFullDetailRow("Allergies", patient.allergies!),
//                   if (patient.medications != null)
//                     _buildFullDetailRow("Medications", patient.medications!),
//                 ],

//                 // Checklist section
//                 if (hasChecklist) ...[
//                   const SizedBox(height: 20),
//                   const Divider(color: Colors.white38),
//                   const SizedBox(height: 10),
//                   const Text(
//                     "Medical Checklist",
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.green.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(color: Colors.green),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             Icon(Icons.checklist, color: Colors.green),
//                             SizedBox(width: 8),
//                             Text(
//                               patient.checklistType ?? 'Medical Checklist',
//                               style: TextStyle(
//                                 color: Colors.green,
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ],
//                         ),
//                         SizedBox(height: 8),
//                         if (patient.checklistHospital != null)
//                           Text(
//                             'Hospital: ${patient.checklistHospital}',
//                             style: TextStyle(color: Colors.white70),
//                           ),
//                         SizedBox(height: 12),
//                         ElevatedButton(
//                           onPressed: () =>
//                               _showChecklistDetails(context, patient),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.green,
//                             minimumSize: Size(double.infinity, 40),
//                           ),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(Icons.visibility, size: 18),
//                               SizedBox(width: 8),
//                               Text('View Complete Checklist'),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],

//                 const SizedBox(height: 20),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     ElevatedButton(
//                       onPressed: () => Navigator.pop(context),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.orange,
//                       ),
//                       child: const Text("Edit"),
//                     ),
//                     ElevatedButton(
//                       onPressed: () {
//                         Navigator.pop(context);
//                         _viewMedicalReports(context, patient);
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green,
//                       ),
//                       child: const Text("Medical Reports"),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _viewMedicalReports(
//     BuildContext context,
//     Patient patient,
//   ) async {
//     final provider = Provider.of<VideoSwitcherProvider>(context, listen: false);

//     try {
//       provider.setIsLoadingPatients(true);

//       final reports = await provider.apiService.getReports(patient.patientId);

//       if (reports.isEmpty) {
//         Fluttertoast.showToast(
//           msg: "No medical reports available for ${patient.name}",
//           gravity: ToastGravity.BOTTOM,
//         );
//         provider.setIsLoadingPatients(false);
//         return;
//       }

//       showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//           backgroundColor: const Color(0xFF3D8A8F),
//           title: Text(
//             "Medical Reports - ${patient.name}",
//             style: const TextStyle(color: Colors.white),
//           ),
//           content: SizedBox(
//             width: double.maxFinite,
//             child: ListView.builder(
//               shrinkWrap: true,
//               itemCount: reports.length,
//               itemBuilder: (context, index) {
//                 final report = reports[index];
//                 return ListTile(
//                   leading: const Icon(Icons.description, color: Colors.white),
//                   title: Text(
//                     report.originalName,
//                     style: const TextStyle(color: Colors.white),
//                   ),
//                   subtitle: Text(
//                     "${report.fileType.split('/').last.toUpperCase()} • ${_formatBytes(report.fileSize)}",
//                     style: const TextStyle(color: Colors.white70),
//                   ),
//                   trailing: IconButton(
//                     icon: const Icon(Icons.download, color: Colors.green),
//                     onPressed: () =>
//                         _downloadAndOpenReport(context, patient, report),
//                   ),
//                 );
//               },
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text("Close", style: TextStyle(color: Colors.white)),
//             ),
//           ],
//         ),
//       );
//     } catch (e) {
//       Fluttertoast.showToast(
//         msg: "Error loading reports: $e",
//         gravity: ToastGravity.BOTTOM,
//       );
//     } finally {
//       provider.setIsLoadingPatients(false);
//     }
//   }

//   Future<void> _downloadAndOpenReport(
//     BuildContext context,
//     Patient patient,
//     Report report,
//   ) async {
//     try {
//       Fluttertoast.showToast(
//         msg: "Downloading ${report.originalName}...",
//         gravity: ToastGravity.BOTTOM,
//       );

//       final provider = Provider.of<VideoSwitcherProvider>(
//         context,
//         listen: false,
//       );

//       final bytes = await provider.apiService.downloadReport(
//         patient.patientId,
//         report.id,
//       );

//       final directory = await getTemporaryDirectory();
//       final filePath = '${directory.path}/${report.originalName}';
//       final file = File(filePath);
//       await file.writeAsBytes(bytes);

//       final isPdf = report.fileType.toLowerCase().contains('pdf');
//       final isImage =
//           report.fileType.toLowerCase().contains('jpg') ||
//           report.fileType.toLowerCase().contains('jpeg') ||
//           report.fileType.toLowerCase().contains('png');

//       if (isPdf || isImage) {
//         // You'll need to add your FileViewerScreen here
//       } else {
//         final result = await OpenFilex.open(filePath);
//         if (result.type != ResultType.done) {
//           Fluttertoast.showToast(
//             msg: "Failed to open file: ${result.message}",
//             gravity: ToastGravity.BOTTOM,
//             backgroundColor: Colors.red,
//           );
//         }
//       }
//     } catch (e) {
//       Fluttertoast.showToast(
//         msg: "Error downloading report: $e",
//         gravity: ToastGravity.BOTTOM,
//         backgroundColor: Colors.red,
//       );
//     }
//   }

//   Widget _buildFullDetailRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: const TextStyle(color: Colors.white70, fontSize: 14),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             value,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFullScreenView(BuildContext context) {
//     final provider = Provider.of<VideoSwitcherProvider>(context);

//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           RepaintBoundary(
//             key: provider.repaintKey,
//             child: Container(
//               width: double.infinity,
//               height: double.infinity,
//               color: Colors.black,
//               child: _getWebViewByIndex(context, provider.selectedStreamIndex),
//             ),
//           ),

//           if (provider.isRecording)
//             Positioned(
//               top: 15,
//               left: 15,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 6,
//                 ),
//                 decoration: BoxDecoration(
//                   color: Colors.black87,
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: Row(
//                   children: [
//                     const Icon(Icons.circle, color: Colors.red, size: 12),
//                     const SizedBox(width: 8),
//                     Text(
//                       "${_getDuration(provider.recordingStartTime)} | ${_formatBytes(provider.bytesDownloaded)}",
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//           Positioned(
//             top: 40,
//             right: 20,
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.black54,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: IconButton(
//                 icon: const Icon(
//                   Icons.fullscreen_exit,
//                   color: Colors.white,
//                   size: 30,
//                 ),
//                 onPressed: () => provider.toggleFullScreen(),
//               ),
//             ),
//           ),

//           Positioned(
//             top: 40,
//             left: provider.isRecording ? 180 : 20,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//               decoration: BoxDecoration(
//                 color: Colors.black54,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Text(
//                 provider.cctvList.isNotEmpty
//                     ? provider.cctvList[provider.selectedStreamIndex]['name']
//                     : 'SOURCE 1',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ),

//           Positioned(
//             bottom: 20,
//             left: 0,
//             right: 0,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   _buildFullScreenControlBtn(
//                     Icons.videocam,
//                     provider.isRecording ? "Stop" : "Record",
//                     onPressed: () => _toggleRecording(context),
//                   ),
//                   const SizedBox(width: 16),
//                   _buildFullScreenControlBtn(
//                     Icons.camera_alt,
//                     "Screenshot",
//                     onPressed: () => _takeScreenshot(context),
//                   ),
//                   const SizedBox(width: 16),
//                   _buildFullScreenControlBtn(
//                     Icons.fullscreen_exit,
//                     "Exit Full",
//                     onPressed: () => provider.toggleFullScreen(),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFullScreenControlBtn(
//     IconData icon,
//     String label, {
//     VoidCallback? onPressed,
//   }) {
//     return Consumer<VideoSwitcherProvider>(
//       builder: (context, provider, child) {
//         bool hasFolder = provider.usbPath != null && provider.usbConnected;

//         return Column(
//           children: [
//             Stack(
//               children: [
//                 Container(
//                   decoration: BoxDecoration(
//                     color: Colors.black54,
//                     shape: BoxShape.circle,
//                   ),
//                   child: IconButton(
//                     icon: Icon(icon, color: Colors.white, size: 24),
//                     onPressed: onPressed,
//                   ),
//                 ),
//                 if (label.contains("Record") && hasFolder)
//                   Positioned(
//                     top: 2,
//                     right: 2,
//                     child: Container(
//                       padding: const EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: Colors.green,
//                         shape: BoxShape.circle,
//                         border: Border.all(color: Colors.black, width: 1),
//                       ),
//                       child: const Icon(
//                         Icons.check,
//                         size: 10,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//             const SizedBox(height: 4),
//             Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   label,
//                   style: const TextStyle(color: Colors.white, fontSize: 12),
//                 ),
//                 if (label.contains("Record") && hasFolder)
//                   const Icon(Icons.check, size: 10, color: Colors.green),
//               ],
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<VideoSwitcherProvider>(
//       builder: (context, provider, child) {
//         if (provider.isFullScreen) {
//           return _buildFullScreenView(context);
//         }

//         return Scaffold(
//           body: Row(
//             children: [
//               // Left Panel (OR Camera List)
//               Expanded(
//                 flex: 1,
//                 child: Container(
//                   decoration: const BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [
//                         Color.fromARGB(255, 40, 123, 131),
//                         Color.fromARGB(255, 39, 83, 87),
//                       ],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                   ),
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.start,
//                     children: [
//                       const SizedBox(height: 25),
//                       Expanded(
//                         flex: 1,
//                         child: Container(
//                           decoration: const BoxDecoration(
//                             gradient: LinearGradient(
//                               colors: [
//                                 Color.fromARGB(255, 40, 123, 131),
//                                 Color.fromARGB(255, 39, 83, 87),
//                               ],
//                               begin: Alignment.topCenter,
//                               end: Alignment.bottomCenter,
//                             ),
//                           ),
//                           child: Column(
//                             children: [
//                               const SizedBox(height: 16),
//                               const Text(
//                                 "OR Camera",
//                                 style: TextStyle(
//                                   fontSize: 20,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.white,
//                                 ),
//                               ),
//                               const Divider(color: Colors.white38),
//                               const SizedBox(height: 12),
//                               Expanded(
//                                 child: ListView(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 12,
//                                   ),
//                                   children: [
//                                     _buildStreamItem(context, "Source ", 0),
//                                     Row(
//                                       mainAxisAlignment:
//                                           MainAxisAlignment.spaceBetween,
//                                       children: [
//                                         IconButton(
//                                           onPressed: () {
//                                             _selectRecordingDirectory(context);
//                                           },
//                                           icon: Icon(
//                                             Icons.storage_rounded,
//                                             color: Colors.white70,
//                                             size: 28,
//                                           ),
//                                         ),
//                                         IconButton(
//                                           onPressed: () {
//                                             Navigator.push(
//                                               context,
//                                               MaterialPageRoute(
//                                                 builder: (context) =>
//                                                     VideoUploadApp(),
//                                               ),
//                                             );
//                                           },
//                                           icon: Icon(
//                                             Icons.usb,
//                                             color: Colors.white70,
//                                             size: 28,
//                                           ),
//                                         ),
//                                         IconButton(
//                                           onPressed: () {
//                                             _showRecordingsList(context);
//                                           },
//                                           icon: Icon(
//                                             Icons.video_camera_back_rounded,
//                                             color: Colors.white70,
//                                             size: 28,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.only(bottom: 16.0),
//                         child: ElevatedButton(
//                           onPressed: () => Navigator.pop(context),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.red,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 40,
//                               vertical: 12,
//                             ),
//                           ),
//                           child: const Text(
//                             "BACK",
//                             style: TextStyle(
//                               color: Colors.white70,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//               // Center Panel (Main Stream View)
//               Expanded(
//                 flex: 3,
//                 child: Container(
//                   decoration: const BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [
//                         Color.fromARGB(255, 40, 123, 131),
//                         Color.fromARGB(255, 39, 83, 87),
//                       ],
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                     ),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       const SizedBox(height: 10),
//                       const Text(
//                         "TN Shukla EYE Hospital",
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 26,
//                           color: Colors.white,
//                         ),
//                       ),
//                       const SizedBox(height: 6),

//                       if (provider.isRecording || provider.isConverting)
//                         Container(
//                           padding: const EdgeInsets.all(8),
//                           color: Colors.black.withOpacity(0.5),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               if (provider.isRecording) ...[
//                                 const Icon(
//                                   Icons.circle,
//                                   color: Colors.red,
//                                   size: 12,
//                                 ),
//                                 const SizedBox(width: 8),
//                                 Text(
//                                   "RECORDING - ${_getDuration(provider.recordingStartTime)} | ${_formatBytes(provider.bytesDownloaded)}",
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ] else if (provider.isConverting) ...[
//                                 const CircularProgressIndicator(
//                                   color: Colors.red,
//                                   strokeWidth: 2,
//                                 ),
//                                 const SizedBox(width: 8),
//                                 Text(
//                                   "Converting MJPEG to MP4: ${provider.conversionProgress.toStringAsFixed(1)}s",
//                                   style: const TextStyle(color: Colors.white),
//                                 ),
//                               ],
//                             ],
//                           ),
//                         ),

//                       Expanded(
//                         child: Stack(
//                           children: [
//                             Padding(
//                               padding: const EdgeInsets.all(8.0),
//                               child: _buildStreamView(context),
//                             ),
//                             if (provider.isRecording)
//                               Positioned(
//                                 top: 15,
//                                 left: 15,
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 12,
//                                     vertical: 6,
//                                   ),
//                                   decoration: BoxDecoration(
//                                     color: Colors.black87,
//                                     borderRadius: BorderRadius.circular(4),
//                                   ),
//                                   child: Row(
//                                     children: [
//                                       const Icon(
//                                         Icons.circle,
//                                         color: Colors.red,
//                                         size: 12,
//                                       ),
//                                       const SizedBox(width: 8),
//                                       Text(
//                                         "${_getDuration(provider.recordingStartTime)} | ${_formatBytes(provider.bytesDownloaded)}",
//                                         style: const TextStyle(
//                                           color: Colors.white,
//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),

//                       Padding(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 8,
//                           vertical: 8,
//                         ),
//                         child: Column(
//                           children: [
//                             if (provider.isConverting)
//                               Column(
//                                 children: [
//                                   const LinearProgressIndicator(
//                                     color: Colors.red,
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     "Converting MJPEG to MP4: ${provider.conversionProgress.toStringAsFixed(1)}s",
//                                     style: const TextStyle(color: Colors.white),
//                                   ),
//                                   const SizedBox(height: 8),
//                                 ],
//                               ),
//                             Wrap(
//                               alignment: WrapAlignment.center,
//                               spacing: 8,
//                               runSpacing: 8,
//                               children: [
//                                 buildControlBtn(
//                                   provider.isRecording
//                                       ? "Stop Recording"
//                                       : "Record",
//                                   onPressed: () => _toggleRecording(context),
//                                   icon: provider.isRecording
//                                       ? Icons.stop
//                                       : Icons.videocam,
//                                   color: provider.isRecording
//                                       ? Colors.red
//                                       : null,
//                                 ),
//                                 buildControlBtn(
//                                   "Take SS",
//                                   icon: Icons.camera_alt,
//                                   onPressed: () => _takeScreenshot(context),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 8),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//               // Right Panel (Patients List)
//               Expanded(
//                 flex: 1,
//                 child: Container(
//                   decoration: const BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [
//                         Color.fromARGB(255, 40, 123, 131),
//                         Color.fromARGB(255, 39, 83, 87),
//                       ],
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                     ),
//                   ),
//                   child: Column(
//                     children: [
//                       const SizedBox(height: 16),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Padding(
//                             padding: const EdgeInsets.only(top: 24.0, left: 16),
//                             child: const Text(
//                               "Today's Patients",
//                               style: TextStyle(
//                                 fontSize: 22,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.white,
//                               ),
//                             ),
//                           ),
//                           Row(
//                             children: [
//                               Tooltip(
//                                 message: provider.serverOnline
//                                     ? 'Server Online'
//                                     : 'Server Offline',
//                                 child: Icon(
//                                   provider.serverOnline
//                                       ? Icons.cloud_done
//                                       : Icons.cloud_off,
//                                   color: provider.serverOnline
//                                       ? Colors.greenAccent
//                                       : Colors.redAccent,
//                                   size: 20,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                       const Divider(color: Colors.white38),
//                       const SizedBox(height: 8),

//                       Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.all(8),
//                         margin: const EdgeInsets.symmetric(horizontal: 12),
//                         decoration: BoxDecoration(
//                           color: Colors.blue.withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(
//                             color: Colors.blue.withOpacity(0.3),
//                           ),
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(
//                               Icons.meeting_room,
//                               size: 14,
//                               color: Colors.blueAccent,
//                             ),
//                             const SizedBox(width: 6),
//                             Text(
//                               otNumber,
//                               style: const TextStyle(
//                                 color: Colors.blueAccent,
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const SizedBox(width: 6),
//                             Icon(
//                               Icons.calendar_today,
//                               size: 14,
//                               color: Colors.blueAccent,
//                             ),
//                             const SizedBox(width: 6),
//                             Text(
//                               _getTodayDate(),
//                               style: const TextStyle(
//                                 color: Colors.blueAccent,
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),

//                       Padding(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 12,
//                           vertical: 8,
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               "OT: $otNumber",
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             IconButton(
//                               onPressed: () => _loadPatients(provider),
//                               icon: const Icon(
//                                 Icons.refresh,
//                                 color: Colors.white,
//                                 size: 20,
//                               ),
//                               tooltip: "Refresh patients for current OT",
//                             ),
//                           ],
//                         ),
//                       ),

//                       Padding(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 12,
//                           vertical: 8,
//                         ),
//                         child: Row(
//                           children: [
//                             Expanded(
//                               child: Container(
//                                 height: 40,
//                                 decoration: BoxDecoration(
//                                   color: Colors.white.withOpacity(0.1),
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 child: const Row(
//                                   children: [
//                                     Padding(
//                                       padding: EdgeInsets.symmetric(
//                                         horizontal: 12,
//                                       ),
//                                       child: Icon(
//                                         Icons.search,
//                                         color: Colors.white70,
//                                       ),
//                                     ),
//                                     Expanded(
//                                       child: TextField(
//                                         style: TextStyle(color: Colors.white),
//                                         decoration: InputDecoration(
//                                           hintText: "Search patients...",
//                                           hintStyle: TextStyle(
//                                             color: Colors.white70,
//                                           ),
//                                           border: InputBorder.none,
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),

//                       if (provider.currentIp.isNotEmpty)
//                         Container(
//                           width: double.infinity,
//                           padding: const EdgeInsets.all(4),
//                           margin: const EdgeInsets.symmetric(
//                             vertical: 4,
//                             horizontal: 12,
//                           ),
//                           decoration: BoxDecoration(
//                             color: Colors.black.withOpacity(0.2),
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                           child: Text(
//                             'Connected to: ${provider.currentIp}',
//                             textAlign: TextAlign.center,
//                             style: const TextStyle(
//                               color: Colors.white70,
//                               fontSize: 10,
//                             ),
//                           ),
//                         ),

//                       if (provider.patientError.isNotEmpty)
//                         Container(
//                           width: double.infinity,
//                           padding: const EdgeInsets.all(8),
//                           margin: const EdgeInsets.symmetric(
//                             horizontal: 12,
//                             vertical: 4,
//                           ),
//                           decoration: BoxDecoration(
//                             color: Colors.orange.withOpacity(0.2),
//                             borderRadius: BorderRadius.circular(4),
//                             border: Border.all(color: Colors.orange),
//                           ),
//                           child: Text(
//                             provider.patientError,
//                             style: const TextStyle(
//                               color: Colors.orange,
//                               fontSize: 11,
//                             ),
//                             textAlign: TextAlign.center,
//                           ),
//                         ),

//                       const SizedBox(height: 4),

//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 12),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               "Total: ${provider.patientsList.length} patients",
//                               style: const TextStyle(
//                                 color: Colors.white70,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             Text(
//                               "Sorted by Time",
//                               style: const TextStyle(
//                                 color: Colors.white70,
//                                 fontSize: 10,
//                                 fontStyle: FontStyle.italic,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),

//                       const SizedBox(height: 8),

//                       Expanded(
//                         child: provider.isLoadingPatients
//                             ? const Center(
//                                 child: Column(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     CircularProgressIndicator(
//                                       color: Colors.white,
//                                     ),
//                                     SizedBox(height: 16),
//                                     Text(
//                                       "Loading patients...",
//                                       style: TextStyle(color: Colors.white70),
//                                     ),
//                                   ],
//                                 ),
//                               )
//                             : provider.patientsList.isEmpty
//                             ? Center(
//                                 child: Column(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     const Icon(
//                                       Icons.people_outline,
//                                       color: Colors.white70,
//                                       size: 50,
//                                     ),
//                                     const SizedBox(height: 16),
//                                     Text(
//                                       "No patients scheduled",
//                                       style: const TextStyle(
//                                         color: Colors.white70,
//                                         fontSize: 16,
//                                       ),
//                                     ),
//                                     const SizedBox(height: 4),
//                                     Text(
//                                       "for OT $otNumber today",
//                                       style: const TextStyle(
//                                         color: Colors.white60,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                     const SizedBox(height: 8),
//                                     Text(
//                                       _getTodayDate(),
//                                       style: const TextStyle(
//                                         color: Colors.white60,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                     const SizedBox(height: 16),
//                                     ElevatedButton(
//                                       onPressed: () => _loadPatients(provider),
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor: Colors.blueAccent,
//                                       ),
//                                       child: const Text("Refresh"),
//                                     ),
//                                   ],
//                                 ),
//                               )
//                             : ListView.builder(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 12,
//                                 ),
//                                 itemCount: provider.patientsList.length,
//                                 itemBuilder: (context, index) {
//                                   return _buildPatientCard(
//                                     context,
//                                     provider.patientsList[index],
//                                     index,
//                                   );
//                                 },
//                               ),
//                       ),

//                       Padding(
//                         padding: const EdgeInsets.all(12),
//                         child: ElevatedButton.icon(
//                           onPressed: () => _showAddPatientDialog(context),
//                           icon: const Icon(Icons.person_add, size: 18),
//                           label: const Text("Add New Patient"),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.green,
//                             foregroundColor: Colors.white,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             minimumSize: const Size(double.infinity, 45),
//                           ),
//                         ),
//                       ),
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

//   void _showAddPatientDialog(BuildContext context) {
//     final provider = Provider.of<VideoSwitcherProvider>(context, listen: false);
//     final nameController = TextEditingController();
//     final ageController = TextEditingController();
//     final genderController = TextEditingController();
//     final phoneController = TextEditingController();
//     final otController = TextEditingController(
//       text: otNumber,
//     ); // Default to current OT
//     final dateController = TextEditingController(text: _getTodayDate());
//     final timeController = TextEditingController();

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: const Color(0xFF3D8A8F),
//         title: const Text(
//           'Add New Patient',
//           style: TextStyle(color: Colors.white),
//         ),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               TextField(
//                 controller: nameController,
//                 style: const TextStyle(color: Colors.white),
//                 decoration: const InputDecoration(
//                   labelText: 'Full Name*',
//                   labelStyle: TextStyle(color: Colors.white70),
//                   border: OutlineInputBorder(),
//                   enabledBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white70),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 10),
//               TextField(
//                 controller: ageController,
//                 style: const TextStyle(color: Colors.white),
//                 decoration: const InputDecoration(
//                   labelText: 'Age*',
//                   labelStyle: TextStyle(color: Colors.white70),
//                   border: OutlineInputBorder(),
//                   enabledBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white70),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white),
//                   ),
//                 ),
//                 keyboardType: TextInputType.number,
//               ),
//               const SizedBox(height: 10),
//               TextField(
//                 controller: genderController,
//                 style: const TextStyle(color: Colors.white),
//                 decoration: const InputDecoration(
//                   labelText: 'Gender*',
//                   labelStyle: TextStyle(color: Colors.white70),
//                   border: OutlineInputBorder(),
//                   enabledBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white70),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 10),
//               TextField(
//                 controller: phoneController,
//                 style: const TextStyle(color: Colors.white),
//                 decoration: const InputDecoration(
//                   labelText: 'Phone*',
//                   labelStyle: TextStyle(color: Colors.white70),
//                   border: OutlineInputBorder(),
//                   enabledBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white70),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white),
//                   ),
//                 ),
//                 keyboardType: TextInputType.phone,
//               ),
//               const SizedBox(height: 10),
//               TextField(
//                 controller: otController,
//                 style: const TextStyle(color: Colors.white),
//                 decoration: const InputDecoration(
//                   labelText: 'OT Number',
//                   labelStyle: TextStyle(color: Colors.white70),
//                   border: OutlineInputBorder(),
//                   enabledBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white70),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 10),
//               TextField(
//                 controller: dateController,
//                 style: const TextStyle(color: Colors.white),
//                 decoration: const InputDecoration(
//                   labelText: 'Operation Date',
//                   labelStyle: TextStyle(color: Colors.white70),
//                   border: OutlineInputBorder(),
//                   enabledBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white70),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 10),
//               TextField(
//                 controller: timeController,
//                 style: const TextStyle(color: Colors.white),
//                 decoration: const InputDecoration(
//                   labelText: 'Operation Time (HH:MM)',
//                   labelStyle: TextStyle(color: Colors.white70),
//                   border: OutlineInputBorder(),
//                   enabledBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white70),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Cancel', style: TextStyle(color: Colors.white)),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               if (nameController.text.isEmpty ||
//                   ageController.text.isEmpty ||
//                   genderController.text.isEmpty ||
//                   phoneController.text.isEmpty) {
//                 Fluttertoast.showToast(
//                   msg: 'Please fill all required fields',
//                   gravity: ToastGravity.BOTTOM,
//                 );
//                 return;
//               }

//               try {
//                 final patient = Patient(
//                   patientId: 'PAT${DateTime.now().millisecondsSinceEpoch}',
//                   name: nameController.text,
//                   age: int.tryParse(ageController.text) ?? 0,
//                   gender: genderController.text,
//                   phone: phoneController.text,
//                   operationOt: otController.text,
//                   operationDate: dateController.text.isNotEmpty
//                       ? dateController.text
//                       : _getTodayDate(),
//                   operationTime: timeController.text,
//                 );

//                 // Only add to list if patient belongs to current OT
//                 if (patient.operationOt == otNumber &&
//                     (patient.operationDate == null ||
//                         patient.operationDate == _getTodayDate())) {
//                   final updatedList = List<Patient>.from(provider.patientsList);
//                   updatedList.add(patient);

//                   updatedList.sort((a, b) {
//                     final timeA = a.operationTime ?? '';
//                     final timeB = b.operationTime ?? '';
//                     return timeA.compareTo(timeB);
//                   });

//                   provider.setPatientsList(updatedList);
//                 }

//                 Navigator.of(context).pop();
//                 Fluttertoast.showToast(
//                   msg: 'Patient added to local list',
//                   gravity: ToastGravity.BOTTOM,
//                 );
//               } catch (e) {
//                 Fluttertoast.showToast(
//                   msg: 'Error adding patient: $e',
//                   gravity: ToastGravity.BOTTOM,
//                 );
//               }
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//             child: const Text('Add Patient'),
//           ),
//         ],
//       ),
//     );
//   }

//   // ==================== FIXED RECORDING METHODS ====================

//   String _getDuration(DateTime? startTime) {
//     if (startTime == null) return "00:00";
//     final diff = DateTime.now().difference(startTime);
//     return "${diff.inMinutes.toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
//   }

//   void _showMessage(String msg) {
//     if (!mounted) return;
//     Fluttertoast.showToast(
//       msg: msg,
//       gravity: ToastGravity.BOTTOM,
//       backgroundColor: Colors.blue,
//     );
//   }

//   Future<void> _requestPermissions() async {
//     if (Platform.isAndroid) {
//       try {
//         final deviceInfo = DeviceInfoPlugin();
//         final androidInfo = await deviceInfo.androidInfo;
//         final sdkInt = androidInfo.version.sdkInt;

//         print("=== DEBUG: Android SDK Version: $sdkInt ===");

//         await Permission.camera.request();
//         await Permission.microphone.request();

//         if (sdkInt >= 33) {
//           print(
//             "=== DEBUG: Android 13+ detected, requesting media permissions ===",
//           );

//           await Permission.photos.request();
//           await Permission.videos.request();
//           await Permission.audio.request();
//           await Permission.notification.request();
//           await Permission.manageExternalStorage.request();
//         } else {
//           print(
//             "=== DEBUG: Android 12 or below, requesting storage permissions ===",
//           );
//           await Permission.storage.request();
//         }

//         final manageStorageStatus = await Permission.manageExternalStorage
//             .request();
//         print(
//           "=== DEBUG: MANAGE_EXTERNAL_STORAGE status: $manageStorageStatus ===",
//         );
//       } catch (e) {
//         print("=== DEBUG: Error requesting permissions: $e ===");
//       }
//     }
//   }

//   Future<void> _selectRecordingDirectory(BuildContext context) async {
//     final provider = Provider.of<VideoSwitcherProvider>(context, listen: false);

//     try {
//       await _requestPermissions();

//       String? selectedDirectory;

//       try {
//         selectedDirectory = await FilePicker.platform.getDirectoryPath(
//           dialogTitle: 'Select Folder for Recordings',
//         );
//       } catch (e) {
//         print("=== DEBUG: FilePicker error: $e ===");
//       }

//       if (selectedDirectory == null || selectedDirectory.isEmpty) {
//         final result = await showDialog<String>(
//           context: context,
//           builder: (context) => AlertDialog(
//             backgroundColor: const Color(0xFF3D8A8F),
//             title: const Text(
//               'Select Storage Location',
//               style: TextStyle(color: Colors.white),
//             ),
//             content: const Text(
//               'Would you like to use the default app storage or select a different folder?',
//               style: TextStyle(color: Colors.white70),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context, 'default'),
//                 child: const Text(
//                   'Use Default',
//                   style: TextStyle(color: Colors.white),
//                 ),
//               ),
//               TextButton(
//                 onPressed: () => Navigator.pop(context, 'select'),
//                 child: const Text(
//                   'Select Folder',
//                   style: TextStyle(color: Colors.white),
//                 ),
//               ),
//             ],
//           ),
//         );

//         if (result == 'select') {
//           return _selectRecordingDirectory(context);
//         }

//         if (Platform.isAndroid) {
//           final externalDir = await getExternalStorageDirectory();
//           if (externalDir != null) {
//             selectedDirectory = '${externalDir.path}/Recordings';
//           } else {
//             final appDir = await getApplicationDocumentsDirectory();
//             selectedDirectory = '${appDir.path}/Recordings';
//           }
//         } else {
//           final appDir = await getApplicationDocumentsDirectory();
//           selectedDirectory = '${appDir.path}/Recordings';
//         }
//       }

//       if (selectedDirectory != null) {
//         final directory = Directory(selectedDirectory);
//         if (!await directory.exists()) {
//           await directory.create(recursive: true);
//         }

//         final prefs = await SharedPreferences.getInstance();

//         final testFile = File('$selectedDirectory/test_permission.txt');
//         try {
//           await testFile.writeAsString('test', flush: true);
//           await testFile.delete();

//           provider.setUsbPath(selectedDirectory);
//           provider.setUsbConnected(true);

//           await prefs.setString("usbPath", selectedDirectory);

//           print(
//             "=== DEBUG: Saved USB path to SharedPreferences: $selectedDirectory ===",
//           );

//           Fluttertoast.showToast(
//             msg: "Recording folder saved: ${path.basename(selectedDirectory)}",
//             gravity: ToastGravity.BOTTOM,
//             backgroundColor: Colors.green,
//           );

//           print("=== DEBUG: Selected directory: $selectedDirectory ===");
//         } catch (e) {
//           print("=== DEBUG: Cannot write to directory: $e ===");

//           final appDir = await getApplicationDocumentsDirectory();
//           final fallbackDir = Directory('${appDir.path}/Recordings');
//           if (!await fallbackDir.exists()) {
//             await fallbackDir.create(recursive: true);
//           }

//           final fallbackPath = fallbackDir.path;
//           provider.setUsbPath(fallbackPath);
//           provider.setUsbConnected(true);

//           await prefs.setString("usbPath", fallbackPath);

//           print(
//             "=== DEBUG: Saved fallback path to SharedPreferences: $fallbackPath ===",
//           );

//           Fluttertoast.showToast(
//             msg: "Using app's private storage for recordings",
//             gravity: ToastGravity.BOTTOM,
//             backgroundColor: Colors.orange,
//           );
//         }
//       }
//     } catch (e) {
//       print("=== DEBUG: Error selecting directory: $e ===");
//       Fluttertoast.showToast(
//         msg: "Error selecting folder: ${e.toString()}",
//         gravity: ToastGravity.BOTTOM,
//         backgroundColor: Colors.red,
//       );
//     }
//   }

//   Future<void> _toggleRecording(BuildContext context) async {
//     final provider = Provider.of<VideoSwitcherProvider>(context, listen: false);

//     if (!provider.isRecording) {
//       if (provider.usbPath == null || !provider.usbConnected) {
//         final bool? shouldSelect = await showDialog<bool>(
//           context: context,
//           builder: (context) => AlertDialog(
//             backgroundColor: const Color(0xFF3D8A8F),
//             title: const Text(
//               'Select Recording Folder',
//               style: TextStyle(color: Colors.white),
//             ),
//             content: const Text(
//               'You need to select a folder to save recordings. Would you like to select a folder now?',
//               style: TextStyle(color: Colors.white70),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context, false),
//                 child: const Text(
//                   'Cancel',
//                   style: TextStyle(color: Colors.white),
//                 ),
//               ),
//               ElevatedButton(
//                 onPressed: () => Navigator.pop(context, true),
//                 style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                 child: const Text('Select Folder'),
//               ),
//             ],
//           ),
//         );

//         if (shouldSelect != true) {
//           return;
//         }

//         await _selectRecordingDirectory(context);

//         if (provider.usbPath == null) {
//           _showMessage("Recording folder not selected");
//           return;
//         }
//       }

//       await _startRecording(provider);
//     } else {
//       await _stopRecording(provider);
//     }
//   }

//   Future<void> _startRecording(VideoSwitcherProvider provider) async {
//     try {
//       Directory? directory;

//       if (provider.usbPath != null && provider.usbConnected) {
//         directory = Directory(provider.usbPath!);
//       }

//       if (directory == null) {
//         if (Platform.isAndroid) {
//           directory = await getExternalStorageDirectory();
//           if (directory == null) {
//             directory = await getApplicationDocumentsDirectory();
//           }
//         } else {
//           directory = await getApplicationDocumentsDirectory();
//         }
//       }

//       if (directory == null) {
//         _showMessage("Cannot access storage");
//         return;
//       }

//       final recordingsDir = Directory('${directory.path}/Recordings');
//       if (!await recordingsDir.exists()) {
//         await recordingsDir.create(recursive: true);
//       }

//       final timestamp = DateTime.now().millisecondsSinceEpoch;
//       final dateStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());

//       String streamName = 'SOURCE_1';
//       if (provider.cctvList.isNotEmpty) {
//         final cctv = provider.cctvList[provider.selectedStreamIndex];
//         streamName =
//             (cctv['name'] as String?)
//                 ?.replaceAll(' ', '_')
//                 .replaceAll('/', '_')
//                 .replaceAll('\\', '_') ??
//             'SOURCE_1';
//       }

//       final safeFileName = '${streamName}_${dateStr}_$timestamp.mjpeg';
//       final recordingPath = '${recordingsDir.path}/$safeFileName';

//       print("=== DEBUG: Recording path: $recordingPath ===");

//       final file = File(recordingPath);
//       try {
//         await file.create(recursive: true);
//         print("=== DEBUG: File created successfully ===");

//         provider.setRecordingPath(recordingPath);
//         provider.setFileSink(file.openWrite(mode: FileMode.writeOnly));
//         provider.setCancelToken(CancelToken());
//         provider.setBytesDownloaded(0);
//         provider.setRecordingStartTime(DateTime.now());
//         provider.setIsRecording(true);

//         provider.setUiTimer(
//           Timer.periodic(const Duration(seconds: 1), (timer) {
//             provider.notifyListeners();
//           }),
//         );

//         final streamUrl = provider.cctvList.isNotEmpty
//             ? provider.cctvList[provider.selectedStreamIndex]['url']
//             : 'http://${provider.cameraIp}:9081';

//         print("=== DEBUG: Starting recording from: $streamUrl ===");

//         _startHttpRecording(streamUrl, provider);

//         _showMessage("Recording started...");
//       } catch (e) {
//         print("=== DEBUG: Error creating file: $e ===");
//         _showMessage("Cannot write to storage: ${e.toString()}");
//         return;
//       }
//     } catch (e) {
//       print("=== DEBUG: Error starting recording: $e ===");
//       _showMessage("Failed to start recording: ${e.toString()}");
//       await _stopRecording(provider);
//     }
//   }

//   Future<void> _startHttpRecording(
//     String streamUrl,
//     VideoSwitcherProvider provider,
//   ) async {
//     final client = http.Client();

//     try {
//       print("=== DEBUG: Connecting to stream: $streamUrl ===");

//       final request = http.Request('GET', Uri.parse(streamUrl));
//       final streamedResponse = await client.send(request);

//       if (streamedResponse.statusCode != 200) {
//         print(
//           "=== DEBUG: Stream returned status: ${streamedResponse.statusCode} ===",
//         );
//         _showMessage("Stream error: HTTP ${streamedResponse.statusCode}");
//         return;
//       }

//       print("=== DEBUG: Stream connected successfully ===");

//       unawaited(_streamHttpRecordingData(streamedResponse.stream, provider));
//     } catch (e) {
//       print("=== DEBUG: HTTP request error: $e ===");
//       _showMessage("Failed to connect to stream: ${e.toString()}");
//       await _stopRecording(provider);
//     }
//   }

//   Future<void> _streamHttpRecordingData(
//     Stream<List<int>> stream,
//     VideoSwitcherProvider provider,
//   ) async {
//     try {
//       await for (List<int> chunk in stream) {
//         if (provider.cancelToken?.isCancelled ?? true) {
//           print("=== DEBUG: Recording cancelled by user ===");
//           break;
//         }

//         if (provider.fileSink != null) {
//           try {
//             provider.fileSink!.add(chunk);
//             provider.setBytesDownloaded(
//               provider.bytesDownloaded + chunk.length,
//             );
//           } catch (e) {
//             print("=== DEBUG: Error writing to file: $e ===");
//             break;
//           }
//         } else {
//           print("=== DEBUG: File sink is null ===");
//           break;
//         }
//       }
//     } catch (e) {
//       print("=== DEBUG: Stream error: $e ===");
//       if (!(provider.cancelToken?.isCancelled ?? false)) {
//         _showMessage("Stream error: ${e.toString()}");
//       }
//     } finally {
//       if (provider.isRecording) {
//         await _stopRecording(provider);
//       }
//     }
//   }

//   Future<void> _stopRecording(VideoSwitcherProvider provider) async {
//     try {
//       print("=== DEBUG: Stopping recording... ===");

//       provider.setUiTimer(null);

//       if (provider.cancelToken != null && !provider.cancelToken!.isCancelled) {
//         provider.cancelToken!.cancel("Recording stopped by user");
//       }
//       provider.setCancelToken(null);

//       if (provider.fileSink != null) {
//         try {
//           await provider.fileSink!.flush();
//           await provider.fileSink!.close();
//           print("=== DEBUG: File sink closed successfully ===");
//         } catch (e) {
//           print("=== DEBUG: Error closing file sink: $e ===");
//         } finally {
//           provider.setFileSink(null);
//         }
//       }

//       provider.setIsRecording(false);

//       await Future.delayed(const Duration(milliseconds: 500));

//       if (provider.recordingPath != null) {
//         final file = File(provider.recordingPath!);
//         if (await file.exists()) {
//           final fileSize = await file.length();

//           print("=== DEBUG: Recording saved: ${provider.recordingPath} ===");
//           print("=== DEBUG: File size: ${fileSize} bytes ===");

//           if (fileSize > 1024) {
//             String saveLocation = "";
//             if (provider.usbPath != null) {
//               saveLocation = "${path.basename(provider.usbPath!)}/Recordings";
//             } else {
//               saveLocation = "Recordings folder";
//             }

//             _showMessage(
//               "Recording saved successfully!\nSize: ${_formatBytes(fileSize)}",
//             );

//             await _convertToMp4(provider);
//           } else {
//             _showMessage(
//               "Recording failed - file too small (${fileSize} bytes)",
//             );
//             try {
//               await file.delete();
//             } catch (e) {
//               print("=== DEBUG: Error deleting small file: $e ===");
//             }
//           }
//         } else {
//           _showMessage("Recording file was not created");
//         }
//       } else {
//         _showMessage("No recording path specified");
//       }
//     } catch (e) {
//       print("=== DEBUG: Error stopping recording: $e ===");
//       _showMessage("Error stopping recording: ${e.toString()}");
//     } finally {
//       provider.clearRecordingState();
//     }
//   }

//   Future<void> _convertToMp4(VideoSwitcherProvider provider) async {
//     if (provider.recordingPath == null) {
//       _showMessage("No recording file to convert");
//       return;
//     }

//     final mjpegFile = File(provider.recordingPath!);
//     if (!await mjpegFile.exists()) {
//       _showMessage("Recording file not found");
//       return;
//     }

//     final fileSize = await mjpegFile.length();
//     if (fileSize == 0) {
//       _showMessage("Empty recording file, skipping conversion");
//       await mjpegFile.delete();
//       return;
//     }

//     provider.setIsConverting(true);
//     provider.setConversionProgress(0.0);

//     final mp4Path = provider.recordingPath!.replaceAll('.mjpeg', '.mp4');
//     print("=== DEBUG: Starting conversion to MP4: $mp4Path ===");
//     print("=== DEBUG: Original MJPEG size: ${_formatBytes(fileSize)} ===");

//     final originalMjpegPath = provider.recordingPath!;

//     final command =
//         '-i "${originalMjpegPath}" '
//         '-c:v libx264 '
//         '-preset ultrafast '
//         '-crf 23 '
//         '-pix_fmt yuv420p '
//         '-r 30 '
//         '-g 60 '
//         '-vf "fps=30,format=yuv420p" '
//         '-c:a aac '
//         '-b:a 128k '
//         '-strict experimental '
//         '-y '
//         '"$mp4Path"';

//     print("=== DEBUG: FFmpeg command: $command ===");

//     try {
//       await FFmpegKit.executeAsync(
//         command,
//         (session) async {
//           final returnCode = await session.getReturnCode();
//           provider.setIsConverting(false);

//           if (ReturnCode.isSuccess(returnCode)) {
//             print("=== DEBUG: Conversion successful: $mp4Path ===");

//             final mp4File = File(mp4Path);
//             if (await mp4File.exists()) {
//               final mp4Size = await mp4File.length();
//               print("=== DEBUG: MP4 file size: ${_formatBytes(mp4Size)} ===");

//               if (mp4Size > 1024) {
//                 try {
//                   final videoController = VideoPlayerController.file(mp4File);
//                   await videoController.initialize();
//                   await videoController.dispose();

//                   try {
//                     if (await File(originalMjpegPath).exists()) {
//                       await File(originalMjpegPath).delete();
//                       print(
//                         "=== DEBUG: Original MJPEG file deleted: $originalMjpegPath ===",
//                       );

//                       provider.setRecordingPath(mp4Path);

//                       _showMessage(
//                         "Video converted to MP4 and original MJPEG deleted",
//                       );
//                     }
//                   } catch (deleteError) {
//                     print(
//                       "=== DEBUG: Error deleting MJPEG file: $deleteError ===",
//                     );
//                     _showMessage(
//                       "Converted to MP4 but couldn't delete MJPEG file",
//                     );
//                   }

//                   provider.addCapturedFile(mp4Path);
//                 } catch (e) {
//                   print("=== DEBUG: Converted file not playable: $e ===");
//                   _showMessage(
//                     "Conversion completed but file may not be playable",
//                   );
//                 }
//               } else {
//                 _showMessage(
//                   "Converted file is too small, keeping original MJPEG",
//                 );
//               }
//             } else {
//               _showMessage(
//                 "Converted file was not created, keeping original MJPEG",
//               );
//             }
//           } else {
//             print(
//               "=== DEBUG: Conversion failed with return code: $returnCode ===",
//             );
//             _showMessage("Conversion failed. Keeping original MJPEG file.");
//           }
//         },
//         (log) {
//           final message = log.getMessage();
//           print("FFmpeg log: $message");

//           if (message.contains("time=")) {
//             final regex = RegExp(r'time=(\d+:\d+:\d+\.\d+)');
//             final match = regex.firstMatch(message);
//             if (match != null) {
//               final timeStr = match.group(1)!;
//               final parts = timeStr.split(':');
//               if (parts.length == 3) {
//                 final hours = int.parse(parts[0]);
//                 final minutes = int.parse(parts[1]);
//                 final seconds = double.parse(parts[2]);
//                 final totalSeconds = hours * 3600 + minutes * 60 + seconds;
//                 provider.setConversionProgress(totalSeconds);
//               }
//             }
//           }
//         },
//         (stats) {
//           final time = stats.getTime();
//           if (time > 0) {
//             provider.setConversionProgress(time / 1000.0);
//           }
//         },
//       );
//     } catch (e) {
//       print("=== DEBUG: FFmpeg execution error: $e ===");
//       provider.setIsConverting(false);
//       _showMessage("Conversion error: ${e.toString()}");

//       await _tryAlternativeConversion(provider, mp4Path, originalMjpegPath);
//     }
//   }

//   Future<void> _tryAlternativeConversion(
//     VideoSwitcherProvider provider,
//     String mp4Path,
//     String originalMjpegPath,
//   ) async {
//     print("=== DEBUG: Trying alternative conversion ===");

//     final altCommand1 =
//         '-i "$originalMjpegPath" '
//         '-c:v libx264 '
//         '-preset veryfast '
//         '-pix_fmt yuv420p '
//         '-r 25 '
//         '-y "$mp4Path"';

//     try {
//       await FFmpegKit.execute(altCommand1).then((session) async {
//         final returnCode = await session.getReturnCode();
//         if (ReturnCode.isSuccess(returnCode)) {
//           print("=== DEBUG: Alternative conversion 1 succeeded ===");

//           try {
//             if (await File(originalMjpegPath).exists()) {
//               await File(originalMjpegPath).delete();
//               print(
//                 "=== DEBUG: Original MJPEG file deleted after alternative conversion ===",
//               );
//             }
//           } catch (e) {
//             print(
//               "=== DEBUG: Error deleting MJPEG file after alternative conversion: $e ===",
//             );
//           }

//           _showMessage("Video converted to MP4 (alternative method)");

//           final mp4File = File(mp4Path);
//           if (await mp4File.exists()) {
//             provider.addCapturedFile(mp4Path);
//           }
//         } else {
//           print("=== DEBUG: Alternative 1 failed ===");

//           final altCommand2 =
//               '-i "$originalMjpegPath" '
//               '-c:v mpeg4 '
//               '-q:v 5 '
//               '-y "$mp4Path"';

//           await FFmpegKit.execute(altCommand2).then((session2) async {
//             final returnCode2 = await session2.getReturnCode();
//             if (ReturnCode.isSuccess(returnCode2)) {
//               print("=== DEBUG: Alternative conversion 2 succeeded ===");

//               try {
//                 if (await File(originalMjpegPath).exists()) {
//                   await File(originalMjpegPath).delete();
//                   print(
//                     "=== DEBUG: Original MJPEG file deleted after alternative conversion 2 ===",
//                   );
//                 }
//               } catch (e) {
//                 print(
//                   "=== DEBUG: Error deleting MJPEG file after alternative conversion 2: $e ===",
//                 );
//               }

//               _showMessage("Video converted to MP4 (MPEG4 format)");

//               final mp4File = File(mp4Path);
//               if (await mp4File.exists()) {
//                 provider.addCapturedFile(mp4Path);
//               }
//             } else {
//               print("=== DEBUG: Alternative 2 also failed ===");
//               _showMessage(
//                 "All conversion attempts failed. Keeping MJPEG file.",
//               );
//             }
//           });
//         }
//       });
//     } catch (e) {
//       print("=== DEBUG: Alternative conversion error: $e ===");
//       _showMessage("Conversion failed. Original MJPEG file kept.");
//     }
//   }

//   Future<List<FileSystemEntity>> _getFiles() async {
//     final provider = Provider.of<VideoSwitcherProvider>(context, listen: false);

//     List<Directory> directories = [];

//     if (provider.usbPath != null && provider.usbConnected) {
//       directories.add(Directory(provider.usbPath!));
//     }

//     final appDir = await getApplicationDocumentsDirectory();
//     directories.add(Directory('${appDir.path}/Recordings'));

//     if (Platform.isAndroid) {
//       final externalDir = await getExternalStorageDirectory();
//       if (externalDir != null) {
//         directories.add(Directory('${externalDir.path}/Recordings'));
//       }
//     }

//     List<FileSystemEntity> allFiles = [];

//     for (var dir in directories) {
//       try {
//         if (await dir.exists()) {
//           final recordingsDir = Directory('${dir.path}/Recordings');
//           if (await recordingsDir.exists()) {
//             final files = await recordingsDir.list().toList();
//             final videoFiles = files.where((f) {
//               final lowerPath = f.path.toLowerCase();
//               return lowerPath.endsWith('.mp4');
//             }).toList();
//             allFiles.addAll(videoFiles);
//           }
//         }
//       } catch (e) {
//         print("=== DEBUG: Error reading directory ${dir.path}: $e ===");
//       }
//     }

//     final uniqueFiles = <String, FileSystemEntity>{};
//     for (var file in allFiles) {
//       uniqueFiles[file.path] = file;
//     }

//     return uniqueFiles.values.toList();
//   }

//   void _showRecordingsList(BuildContext context) async {
//     try {
//       final provider = Provider.of<VideoSwitcherProvider>(
//         context,
//         listen: false,
//       );
//       provider.setIsLoading(true);

//       final files = await _getFiles();

//       if (!mounted) return;
//       provider.setIsLoading(false);

//       if (files.isEmpty) {
//         showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//             title: const Text('No Recordings'),
//             content: const Text('No video recordings found.'),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text('OK'),
//               ),
//             ],
//           ),
//         );
//         return;
//       }

//       files.sort((a, b) {
//         final statA = a.statSync();
//         final statB = b.statSync();
//         return statB.modified.compareTo(statA.modified);
//       });

//       showModalBottomSheet(
//         context: context,
//         isScrollControlled: true,
//         backgroundColor: Colors.grey[900],
//         builder: (ctx) => Container(
//           height: MediaQuery.of(context).size.height * 0.7,
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     'Recorded Videos',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.close, color: Colors.white),
//                     onPressed: () => Navigator.pop(ctx),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: files.length,
//                   itemBuilder: (ctx, i) {
//                     final file = files[i];
//                     final fileName = path.basename(file.path);

//                     if (fileName.toLowerCase().endsWith('.mjpeg')) {
//                       return const SizedBox.shrink();
//                     }

//                     final fileStat = file.statSync();
//                     final fileSize = fileStat.size;
//                     final modified = fileStat.modified;

//                     return Card(
//                       color: Colors.grey[800],
//                       child: ListTile(
//                         leading: const Icon(Icons.videocam, color: Colors.red),
//                         title: Text(
//                           fileName,
//                           style: const TextStyle(color: Colors.white),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         subtitle: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Size: ${_formatBytes(fileSize)}',
//                               style: const TextStyle(
//                                 color: Colors.white70,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             Text(
//                               'Modified: ${DateFormat('yyyy-MM-dd HH:mm').format(modified)}',
//                               style: const TextStyle(
//                                 color: Colors.white70,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             Container(
//                               margin: EdgeInsets.only(top: 4),
//                               padding: EdgeInsets.symmetric(
//                                 horizontal: 6,
//                                 vertical: 2,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.blue.withOpacity(0.2),
//                                 borderRadius: BorderRadius.circular(4),
//                               ),
//                               child: Text(
//                                 'MP4',
//                                 style: TextStyle(
//                                   color: Colors.blueAccent,
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         trailing: const Icon(
//                           Icons.play_arrow,
//                           color: Colors.green,
//                         ),
//                         onTap: () {
//                           Navigator.pop(ctx);
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (_) => VideoPlayerScreen(
//                                 filePath: file.path,
//                                 fileName: fileName,
//                               ),
//                             ),
//                           );
//                         },
//                         onLongPress: () {
//                           _showFileOptions(context, file.path, fileName);
//                         },
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     } catch (e) {
//       print("=== DEBUG: Error showing recordings list: $e ===");
//       if (mounted) {
//         final provider = Provider.of<VideoSwitcherProvider>(
//           context,
//           listen: false,
//         );
//         provider.setIsLoading(false);
//         _showMessage("Error loading recordings: ${e.toString()}");
//       }
//     }
//   }

//   void _showFileOptions(
//     BuildContext context,
//     String filePath,
//     String fileName,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.grey[900],
//       builder: (ctx) => Container(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ListTile(
//               leading: const Icon(Icons.delete, color: Colors.red),
//               title: const Text(
//                 'Delete',
//                 style: TextStyle(color: Colors.white),
//               ),
//               onTap: () async {
//                 Navigator.pop(ctx);
//                 _deleteRecording(context, filePath, fileName);
//               },
//             ),
//             ListTile(
//               leading: const Icon(Icons.share, color: Colors.blue),
//               title: const Text('Share', style: TextStyle(color: Colors.white)),
//               onTap: () {
//                 Navigator.pop(ctx);
//                 _shareRecording(context, filePath);
//               },
//             ),
//             ListTile(
//               leading: const Icon(Icons.info, color: Colors.yellow),
//               title: const Text(
//                 'File Info',
//                 style: TextStyle(color: Colors.white),
//               ),
//               onTap: () {
//                 Navigator.pop(ctx);
//                 _showFileInfo(context, filePath);
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _deleteRecording(
//     BuildContext context,
//     String filePath,
//     String fileName,
//   ) async {
//     final bool? confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Delete Recording'),
//         content: Text('Are you sure you want to delete "$fileName"?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: TextButton.styleFrom(foregroundColor: Colors.red),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );

//     if (confirm == true) {
//       try {
//         final file = File(filePath);
//         if (await file.exists()) {
//           await file.delete();
//           _showMessage("Recording deleted: $fileName");

//           _showRecordingsList(context);
//         }
//       } catch (e) {
//         _showMessage("Error deleting file: ${e.toString()}");
//       }
//     }
//   }

//   Future<void> _shareRecording(BuildContext context, String filePath) async {
//     try {
//       final file = File(filePath);
//       if (await file.exists()) {
//         _showMessage("Sharing feature requires share_plus package");
//       }
//     } catch (e) {
//       _showMessage("Error sharing file: ${e.toString()}");
//     }
//   }

//   void _showFileInfo(BuildContext context, String filePath) {
//     try {
//       final file = File(filePath);
//       final stat = file.statSync();
//       final fileName = path.basename(filePath);

//       showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: const Text('File Information'),
//           content: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text('Name: $fileName'),
//                 Text('Path: ${path.dirname(filePath)}'),
//                 Text('Size: ${_formatBytes(stat.size)}'),
//                 Text(
//                   'Created: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(stat.changed)}',
//                 ),
//                 Text(
//                   'Modified: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(stat.modified)}',
//                 ),
//                 Text(
//                   'Accessed: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(stat.accessed)}',
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Close'),
//             ),
//           ],
//         ),
//       );
//     } catch (e) {
//       _showMessage("Error getting file info: ${e.toString()}");
//     }
//   }

//   Future<void> checkConnection(VideoSwitcherProvider provider) async {
//     try {
//       final response = await http
//           .get(Uri.parse('$baseUrl/status'))
//           .timeout(const Duration(seconds: 5));

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         provider.setIsConnected(
//           data['connected'].toString().toLowerCase() == 'true',
//         );
//       } else {
//         provider.setIsConnected(false);
//       }
//     } catch (e) {
//       provider.setIsConnected(false);
//     }
//   }

//   Future<void> _takeScreenshot(BuildContext context) async {
//     final provider = Provider.of<VideoSwitcherProvider>(context, listen: false);

//     try {
//       if (!provider.usbConnected || provider.usbPath == null) {
//         Fluttertoast.showToast(
//           msg: "Please select USB storage first",
//           gravity: ToastGravity.BOTTOM,
//         );
//         return;
//       }

//       await Future.delayed(const Duration(milliseconds: 200));

//       RenderRepaintBoundary boundary =
//           provider.repaintKey.currentContext!.findRenderObject()
//               as RenderRepaintBoundary;

//       ui.Image image = await boundary.toImage(pixelRatio: 3.0);
//       ByteData? byteData = await image.toByteData(
//         format: ui.ImageByteFormat.png,
//       );

//       if (byteData == null) {
//         throw Exception("Failed to capture screenshot bytes");
//       }

//       Uint8List pngBytes = byteData.buffer.asUint8List();

//       final screenshotDir = Directory(
//         path.join(provider.usbPath!, 'Screenshots'),
//       );
//       if (!await screenshotDir.exists()) {
//         await screenshotDir.create(recursive: true);
//       }

//       final cctvName = provider.cctvList.isNotEmpty
//           ? provider.cctvList[provider.selectedStreamIndex]['name']
//           : 'SOURCE 1';
//       final fileName =
//           '${cctvName}_screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
//       final file = File(path.join(screenshotDir.path, fileName));
//       await file.writeAsBytes(pngBytes);

//       Fluttertoast.showToast(
//         msg:
//             "Screenshot saved: $fileName\nSize: ${file.lengthSync() ~/ 1024} KB",
//         gravity: ToastGravity.BOTTOM,
//         backgroundColor: Colors.green,
//       );
//     } catch (e) {
//       print("Failed to capture screenshot: $e");
//       Fluttertoast.showToast(
//         msg: "Failed to capture screenshot",
//         gravity: ToastGravity.BOTTOM,
//         backgroundColor: Colors.red,
//       );
//     }
//   }

//   Widget _buildStreamView(BuildContext context) {
//     final provider = Provider.of<VideoSwitcherProvider>(context);

//     return Stack(
//       children: [
//         RepaintBoundary(
//           key: provider.repaintKey,
//           child: Container(
//             width: double.infinity,
//             height: double.infinity,
//             color: Colors.black,
//             child: _getWebViewByIndex(context, provider.selectedStreamIndex),
//           ),
//         ),

//         Positioned(
//           top: 10,
//           right: 10,
//           child: Container(
//             decoration: BoxDecoration(
//               color: Colors.black.withOpacity(0.5),
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: IconButton(
//               icon: Icon(Icons.fullscreen, color: Colors.white, size: 24),
//               onPressed: () => provider.toggleFullScreen(),
//               tooltip: "Enter Full Screen",
//             ),
//           ),
//         ),

//         if (provider.isRecording)
//           Positioned(
//             top: 10,
//             left: 10,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.7),
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(color: Colors.red, width: 1),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.circle, color: Colors.red, size: 12),
//                   SizedBox(width: 6),
//                   Text(
//                     "REC ${_getDuration(provider.recordingStartTime)}",
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   SizedBox(width: 6),
//                   Text(
//                     _formatBytes(provider.bytesDownloaded),
//                     style: TextStyle(color: Colors.white70, fontSize: 10),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//         Positioned(
//           bottom: 10,
//           left: 10,
//           child: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//             decoration: BoxDecoration(
//               color: Colors.black.withOpacity(0.5),
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: Text(
//               provider.cctvList.isNotEmpty
//                   ? provider.cctvList[provider.selectedStreamIndex]['name']
//                   : 'SOURCE 1',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 14,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _getWebViewByIndex(BuildContext context, int index) {
//     final provider = Provider.of<VideoSwitcherProvider>(context, listen: false);
//     return WebViewWidget(controller: provider.obsController);
//   }

//   Widget buildControlBtn(
//     String label, {
//     IconData? icon,
//     VoidCallback? onPressed,
//     Color? color,
//   }) {
//     return Consumer<VideoSwitcherProvider>(
//       builder: (context, provider, child) {
//         bool hasFolder = provider.usbPath != null && provider.usbConnected;
//         IconData folderIcon = hasFolder ? Icons.folder_open : Icons.folder;
//         Color folderColor = hasFolder ? Colors.green : Colors.yellow;

//         return SizedBox(
//           width: 140,
//           child: ElevatedButton.icon(
//             onPressed: onPressed,
//             icon: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 if (icon != null)
//                   Icon(
//                     icon,
//                     size: 16,
//                     color: color != null ? Colors.white : null,
//                   ),
//                 if (label.contains("Record"))
//                   Padding(
//                     padding: const EdgeInsets.only(left: 4),
//                     child: Icon(folderIcon, size: 14, color: folderColor),
//                   ),
//               ],
//             ),
//             label: Text(
//               label,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 color: color != null ? Colors.white : Colors.black,
//               ),
//             ),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: color ?? Colors.white,
//               foregroundColor: color != null ? Colors.white : Colors.black,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(30),
//               ),
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildStreamItem(BuildContext context, String name, int index) {
//     final provider = Provider.of<VideoSwitcherProvider>(context);
//     final isSelected = provider.selectedStreamIndex == index;

//     return InkWell(
//       onTap: () => provider.setSelectedStreamIndex(index),
//       child: Container(
//         padding: const EdgeInsets.all(8),
//         decoration: BoxDecoration(
//           color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(
//             color: isSelected ? Colors.blue : Colors.transparent,
//             width: 1,
//           ),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       name,
//                       style: TextStyle(
//                         color: isSelected
//                             ? Colors.lightGreenAccent
//                             : Colors.white,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 30,
//                       ),
//                     ),
//                     Text(
//                       isSelected ? "LIVE" : "Select to view",
//                       style: TextStyle(
//                         color: isSelected ? Colors.greenAccent : Colors.white70,
//                         fontSize: 28,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),

//             const Divider(color: Colors.white38),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _provider.disposeResources();
//     super.dispose();
//   }
// }
