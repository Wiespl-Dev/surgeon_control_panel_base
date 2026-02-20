import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:wiespl_surgeon_panel/provider/stopwatch_provider.dart';

// import 'package:test_pac/provider/stopwatch_provider.dart'
//     show StopwatchProvider;

class StylishStopwatchPage extends StatelessWidget {
  const StylishStopwatchPage({super.key});

  Widget buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [color.withOpacity(0.9), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.6),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stopwatchProvider = Provider.of<StopwatchProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 35, 87, 136),
        elevation: 0,
        title: const Text(
          "Stopwatch",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color.fromARGB(255, 35, 87, 136),
                const Color.fromARGB(255, 35, 87, 136),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Spacer(),
              Center(
                child: StreamBuilder<int>(
                  stream: stopwatchProvider.stopWatchTimer.rawTime,
                  initialData: stopwatchProvider.stopWatchTimer.rawTime.value,
                  builder: (context, snapshot) {
                    final time = StopWatchTimer.getDisplayTime(snapshot.data!);
                    return Text(
                      time,
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  buildControlButton(
                    icon: Icons.restart_alt,
                    color: Colors.indigoAccent,
                    onPressed: stopwatchProvider.reset,
                  ),
                  const SizedBox(width: 30),
                  buildControlButton(
                    icon: stopwatchProvider.isRunning
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: stopwatchProvider.isRunning
                        ? Colors.redAccent
                        : Colors.green,
                    onPressed: stopwatchProvider.toggleRunning,
                  ),
                  const SizedBox(width: 30),
                  buildControlButton(
                    icon: Icons.flag,
                    color: Colors.orange,
                    onPressed: stopwatchProvider.addLap,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text(
                "Lap Times",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.white54,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: stopwatchProvider.lapTimes.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Text(
                        "#${stopwatchProvider.lapTimes.length - index}",
                        style: TextStyle(color: Colors.white70),
                      ),
                      title: Text(
                        stopwatchProvider.lapTimes[index],
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
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
      ),
    );
  }
}
