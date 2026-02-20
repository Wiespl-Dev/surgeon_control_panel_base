import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class HospitalCleaningApp extends StatelessWidget {
  const HospitalCleaningApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3B82F6),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hospital Cleaning Dashboard',
      theme: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(fontFamily: 'Inter'),
      ),
      home: const CleaningDashboard(),
    );
  }
}

class CleaningDashboard extends StatefulWidget {
  const CleaningDashboard({super.key});

  @override
  State<CleaningDashboard> createState() => _CleaningDashboardState();
}

class _CleaningDashboardState extends State<CleaningDashboard>
    with TickerProviderStateMixin {
  // Simulated live metrics
  double cleanliness = 0.82; // 82%
  int roomsCleanedToday = 18;
  int overdueTasks = 2;

  late final AnimationController _pulseCtrl;
  late final AnimationController _tickerCtrl;

  // Weekly cleanliness trend (Mon..Sun)
  final List<double> weeklyCleanliness = [
    0.72,
    0.78,
    0.81,
    0.77,
    0.86,
    0.83,
    0.9,
  ];

  // Rooms cleaned per shift (Morn, Aft, Night)
  final List<int> shiftCounts = [8, 7, 5];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);

    // Ticker to simulate live updates
    _tickerCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _tickerCtrl.forward(from: 0);
              _simulateNextTick();
            }
          })
          ..forward();
  }

  void _simulateNextTick() {
    setState(() {
      // Nudge cleanliness ±3%
      final delta = (math.Random().nextDouble() * 0.06) - 0.03;
      cleanliness = (cleanliness + delta).clamp(0.55, 0.98);
      // Randomly mark a room cleaned
      if (math.Random().nextBool()) roomsCleanedToday += 1;
      // Randomly change overdue
      overdueTasks = math.max(
        0,
        overdueTasks + (math.Random().nextBool() ? 1 : -1),
      );
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _tickerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 112, 143, 214),
              Color.fromARGB(255, 157, 102, 228),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 160,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode:
                    CollapseMode.none, // Prevent background resize effect
                titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
                title: const Text('Cleaning Dashboard'),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 112, 143, 214),
                        Color.fromARGB(255, 157, 102, 228),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              backgroundColor: Colors.transparent, // Keep gradient clean
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  tooltip: 'Sync',
                  icon: const Icon(Icons.sync_rounded),
                  onPressed: _simulateNextTick,
                ),
                const SizedBox(width: 8),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _kpiRow(cs),
                  const SizedBox(height: 16),
                  _meterAndActions(cs),
                  const SizedBox(height: 16),
                  _charts(cs),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiRow(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            title: 'Rooms Cleaned',
            value: roomsCleanedToday.toString(),
            icon: Icons.cleaning_services_rounded,
            chip: 'Today',
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _kpiCard(
            title: 'Avg Cleanliness',
            value: '${(cleanliness * 100).toStringAsFixed(0)}%',
            icon: Icons.percent_rounded,
            chip: 'Live',
            color: cs.tertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _kpiCard(
            title: 'Overdue Tasks',
            value: overdueTasks.toString(),
            icon: Icons.warning_amber_rounded,
            chip: 'Action',
            color: cs.error,
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required String chip,
    required Color color,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      tween: Tween(begin: 0.9, end: 1),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromARGB(41, 255, 255, 255),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(47, 255, 255, 255),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.45)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          chip,
                          style: TextStyle(fontSize: 10, color: color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meterAndActions(ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDeco(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Room Cleanliness',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    height: 190,
                    width: 190,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_pulseCtrl, _tickerCtrl]),
                      builder: (context, _) => _RadialGauge(
                        progress: cleanliness,
                        pulse: _pulseCtrl.value,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '${(cleanliness * 100).toStringAsFixed(1)}% • Disinfected',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDeco(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _actionButton(
                  cs.primary,
                  Icons.play_arrow_rounded,
                  'Start Cleaning',
                  () {},
                ),
                const SizedBox(height: 10),
                _actionButton(
                  Colors.teal,
                  Icons.qr_code_scanner_rounded,
                  'Scan Room QR',
                  () {},
                ),
                const SizedBox(height: 10),
                _actionButton(
                  Colors.orange,
                  Icons.assignment_turned_in_rounded,
                  'Mark Complete',
                  () {},
                ),
                const SizedBox(height: 10),
                _actionButton(
                  Colors.pink,
                  Icons.bug_report_rounded,
                  'Report Issue',
                  () {},
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
    color: const Color.fromARGB(41, 255, 255, 255),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );

  Widget _actionButton(
    Color color,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 8),
          child: child,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _charts(ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDeco(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly Cleanliness Trend',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: 6,
                      minY: 0.5,
                      maxY: 1.0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 0.1,
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 0.1,
                            getTitlesWidget: (v, m) =>
                                Text('${(v * 100).toInt()}%'),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, m) {
                              const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                              return Text(days[v.toInt().clamp(0, 6)]);
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          barWidth: 4,
                          color: cs.primary,
                          belowBarData: BarAreaData(
                            show: true,
                            color: cs.primary.withOpacity(0.15),
                          ),
                          spots: List.generate(
                            weeklyCleanliness.length,
                            (i) => FlSpot(i.toDouble(), weeklyCleanliness[i]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDeco(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rooms Cleaned by Shift',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true, interval: 2),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, m) {
                              const labels = ['Morning', 'Afternoon', 'Night'];
                              final idx = v.toInt();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  idx >= 0 && idx < 3 ? labels[idx] : '',
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(3, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: shiftCounts[i].toDouble(),
                              width: 22,
                              borderRadius: BorderRadius.circular(8),
                              color: [
                                cs.secondary,
                                cs.primary,
                                cs.tertiary,
                              ][i % 3],
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: 12,
                                color: Colors.black12,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RadialGauge extends StatelessWidget {
  final double progress; // 0..1
  final double pulse; // 0..1
  final Color color;
  const _RadialGauge({
    required this.progress,
    required this.pulse,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RadialGaugePainter(
        progress: progress,
        pulse: pulse,
        color: color,
      ),
    );
  }
}

class _RadialGaugePainter extends CustomPainter {
  final double progress;
  final double pulse;
  final Color color;
  _RadialGaugePainter({
    required this.progress,
    required this.pulse,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    // Background circle
    final bg = Paint()
      ..color = const Color(0xFFEAEAEA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bg,
    );

    // Progress arc with subtle pulse width
    final pw = 16 + pulse * 2.5;
    final fg = Paint()
      ..shader = SweepGradient(
        startAngle: math.pi * 0.75,
        endAngle: math.pi * (0.75 + 1.5 * progress),
        colors: [color.withOpacity(0.7), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = pw
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5 * progress,
      false,
      fg,
    );

    // Center text
    final tp = TextPainter(
      text: TextSpan(
        text: '${(progress * 100).toStringAsFixed(0)}%',
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RadialGaugePainter old) =>
      old.progress != progress || old.pulse != pulse || old.color != color;
}
