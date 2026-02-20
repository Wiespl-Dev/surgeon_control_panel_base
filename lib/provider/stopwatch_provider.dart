import 'package:flutter/material.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

class StopwatchProvider extends ChangeNotifier {
  final StopWatchTimer _stopWatchTimer = StopWatchTimer(
    mode: StopWatchMode.countUp,
  );

  bool _isRunning = false;
  List<String> _lapTimes = [];

  StopWatchTimer get stopWatchTimer => _stopWatchTimer;
  bool get isRunning => _isRunning;
  List<String> get lapTimes => _lapTimes;

  void start() {
    _stopWatchTimer.onStartTimer();
    _isRunning = true;
    notifyListeners();
  }

  void stop() {
    _stopWatchTimer.onStopTimer();
    _isRunning = false;
    notifyListeners();
  }

  void reset() {
    _stopWatchTimer.onResetTimer();
    _lapTimes.clear();
    _isRunning = false;
    notifyListeners();
  }

  void toggleRunning() {
    if (_isRunning) {
      stop();
    } else {
      start();
    }
  }

  void addLap() async {
    final rawTime = _stopWatchTimer.rawTime.value;
    final formattedTime = StopWatchTimer.getDisplayTime(rawTime);
    _lapTimes.insert(0, formattedTime);
    notifyListeners();
  }

  @override
  void dispose() {
    _stopWatchTimer.dispose();
    super.dispose();
  }
}
