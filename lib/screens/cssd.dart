// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class CssdApp extends StatelessWidget {
//   const CssdApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData.dark().copyWith(
//         scaffoldBackgroundColor: const Color(0xFF121212),
//         cardTheme: CardThemeData(
//           color: const Color(0xFF1E1E1E),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           elevation: 4,
//         ),
//       ),
//       home: const DashboardScreen(),
//     );
//   }
// }

// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({super.key});

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen>
//     with SingleTickerProviderStateMixin {
//   String selectedMenu = "Dashboard";
//   late AnimationController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 600),
//     )..forward();
//   }

//   void _onMenuSelect(String title) {
//     setState(() {
//       selectedMenu = title;
//       _controller.reset();
//       _controller.forward();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Row(
//         children: [
//           // Sidebar
//           Container(
//             width: 220,
//             color: const Color(0xFF1B1B1B),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const DrawerHeader(
//                   child: Text(
//                     "CSSD Demo Application",
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//                 _buildMenuItem(Icons.dashboard, "Dashboard"),
//                 _buildMenuItem(Icons.scatter_plot, "ScatterChart"),
//                 _buildMenuItem(Icons.star, "RadarChart"),
//                 _buildMenuItem(Icons.show_chart, "LineChart"),
//                 _buildMenuItem(Icons.settings, "Settings"),
//               ],
//             ),
//           ),

//           // Main Content
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: FadeTransition(
//                 opacity: _controller,
//                 child: ScaleTransition(
//                   scale: Tween<double>(begin: 0.95, end: 1.0).animate(
//                     CurvedAnimation(
//                       parent: _controller,
//                       curve: Curves.easeOutBack,
//                     ),
//                   ),
//                   child: _buildContent(),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildMenuItem(IconData icon, String title) {
//     bool selected = title == selectedMenu;
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
//       decoration: BoxDecoration(
//         color: selected ? const Color(0xFF2C2C2C) : Colors.transparent,
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: ListTile(
//         leading: Icon(icon, color: Colors.white),
//         title: Text(title),
//         onTap: () => _onMenuSelect(title),
//       ),
//     );
//   }

//   Widget _buildContent() {
//     switch (selectedMenu) {
//       case "ScatterChart":
//         return _buildScatterChart();
//       case "RadarChart":
//         return _buildRadarChart();
//       case "LineChart":
//         return _buildLineChart();
//       case "Dashboard":
//         return _buildDashboard();
//       default:
//         return Center(
//           child: Text(
//             "$selectedMenu Page Coming Soon...",
//             style: const TextStyle(fontSize: 22, color: Colors.grey),
//           ),
//         );
//     }
//   }

//   Future<void> _logout() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove("uniqueCode");
//     await prefs.remove("mode");
//     Navigator.pushAndRemoveUntil(
//       context,
//       MaterialPageRoute(builder: (context) => const LoginPage()),
//       (route) => false,
//     );
//   }

//   Widget _buildDashboard() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Align(
//           alignment: Alignment.topRight,
//           child: SizedBox(
//             width: 250,
//             child: TextField(
//               onSubmitted: (value) {
//                 ScaffoldMessenger.of(
//                   context,
//                 ).showSnackBar(SnackBar(content: Text("Search for: $value")));
//               },
//               decoration: InputDecoration(
//                 prefixIcon: const Icon(Icons.search),
//                 hintText: "Search",
//                 filled: true,
//                 fillColor: const Color(0xFF1E1E1E),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide.none,
//                 ),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(height: 24),
//         IconButton(
//           onPressed: () {
//             _logout();
//           },
//           icon: Icon(Icons.login_outlined),
//         ),
//         const Text(
//           "Dashboard",
//           style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//         ),
//         const SizedBox(height: 16),

//         Row(
//           children: const [
//             Expanded(
//               child: InfoCard(title: "Total Users", value: "150"),
//             ),
//             SizedBox(width: 16),
//             Expanded(
//               child: InfoCard(title: "Active Users", value: "75"),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         Row(
//           children: const [
//             Expanded(
//               child: InfoCard(title: "New Users", value: "50%"),
//             ),
//             SizedBox(width: 16),
//             Expanded(
//               child: InfoCard(title: "Pending Requests", value: "30"),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildScatterChart() {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: ScatterChart(
//           ScatterChartData(
//             minX: 0,
//             maxX: 8,
//             minY: 0,
//             maxY: 8,
//             scatterSpots: [
//               ScatterSpot(
//                 2,
//                 3,
//                 dotPainter: FlDotCirclePainter(radius: 6, color: Colors.red),
//               ),
//               ScatterSpot(
//                 3,
//                 2,
//                 dotPainter: FlDotCirclePainter(radius: 8, color: Colors.green),
//               ),
//               ScatterSpot(
//                 4,
//                 5,
//                 dotPainter: FlDotCirclePainter(radius: 10, color: Colors.blue),
//               ),
//               ScatterSpot(
//                 7,
//                 7,
//                 dotPainter: FlDotCirclePainter(
//                   radius: 12,
//                   color: Colors.orange,
//                 ),
//               ),
//             ],
//             gridData: const FlGridData(show: true),
//             borderData: FlBorderData(show: true),
//             titlesData: const FlTitlesData(show: true),
//             scatterTouchData: ScatterTouchData(enabled: true),
//           ),
//           swapAnimationDuration: const Duration(milliseconds: 600),
//           swapAnimationCurve: Curves.easeOut,
//         ),
//       ),
//     );
//   }

//   Widget _buildRadarChart() {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: RadarChart(
//           RadarChartData(
//             radarBackgroundColor: Colors.transparent,
//             borderData: FlBorderData(show: false),
//             tickCount: 4,
//             ticksTextStyle: const TextStyle(color: Colors.grey, fontSize: 10),
//             gridBorderData: BorderSide(
//               color: Colors.grey.withOpacity(0.5),
//               width: 1,
//             ),
//             radarShape: RadarShape.polygon,
//             titleTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
//             titlePositionPercentageOffset: 0.15,
//             getTitle: (index, angle) {
//               switch (index) {
//                 case 0:
//                   return RadarChartTitle(text: "Speed", angle: angle);
//                 case 1:
//                   return RadarChartTitle(text: "Power", angle: angle);
//                 case 2:
//                   return RadarChartTitle(text: "Skill", angle: angle);
//                 case 3:
//                   return RadarChartTitle(text: "Agility", angle: angle);
//                 case 4:
//                   return RadarChartTitle(text: "Stamina", angle: angle);
//                 default:
//                   return const RadarChartTitle(text: "");
//               }
//             },
//             dataSets: [
//               RadarDataSet(
//                 dataEntries: const [
//                   RadarEntry(value: 3),
//                   RadarEntry(value: 2),
//                   RadarEntry(value: 5),
//                   RadarEntry(value: 4),
//                   RadarEntry(value: 3),
//                 ],
//                 borderColor: Colors.blue,
//                 fillColor: Colors.blue.withOpacity(0.3),
//               ),
//             ],
//           ),
//           swapAnimationDuration: Duration(milliseconds: 500),
//           swapAnimationCurve: Curves.easeOut,
//         ),
//       ),
//     );
//   }

//   Widget _buildLineChart() {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: LineChart(
//           LineChartData(
//             gridData: const FlGridData(show: true),
//             titlesData: const FlTitlesData(show: true),
//             borderData: FlBorderData(
//               show: true,
//               border: Border.all(color: const Color(0xff37434d), width: 1),
//             ),
//             minX: 0,
//             maxX: 6,
//             minY: 0,
//             maxY: 6,
//             lineBarsData: [
//               LineChartBarData(
//                 spots: const [
//                   FlSpot(0, 3),
//                   FlSpot(1, 1),
//                   FlSpot(2, 4),
//                   FlSpot(3, 2),
//                   FlSpot(4, 5),
//                   FlSpot(5, 3),
//                   FlSpot(6, 4),
//                 ],
//                 isCurved: true,
//                 color: Colors.blue,
//                 dotData: const FlDotData(show: false),
//                 belowBarData: BarAreaData(show: false),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class InfoCard extends StatefulWidget {
//   final String title;
//   final String value;

//   const InfoCard({super.key, required this.title, required this.value});

//   @override
//   State<InfoCard> createState() => _InfoCardState();
// }

// class _InfoCardState extends State<InfoCard> {
//   bool _hovered = false;

//   @override
//   Widget build(BuildContext context) {
//     return MouseRegion(
//       onEnter: (_) => setState(() => _hovered = true),
//       onExit: (_) => setState(() => _hovered = false),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeOut,
//         transform: _hovered
//             ? (Matrix4.identity()..scale(1.05))
//             : (Matrix4.identity()..scale(1.0)),
//         child: Card(
//           child: Padding(
//             padding: const EdgeInsets.all(20.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   widget.value,
//                   style: const TextStyle(
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(widget.title, style: TextStyle(color: Colors.grey[400])),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
