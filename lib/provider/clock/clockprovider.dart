import 'dart:async';

import 'package:flutter/material.dart';

class ClockProvider extends ChangeNotifier {
  late DateTime _now;
  late Timer _timer;

  // Existing getters
  String get hours => _twoDigits(_now.hour);
  String get minutes => _twoDigits(_now.minute);
  String get seconds => _twoDigits(_now.second);
  String get dateString =>
      "${_weekDay(_now.weekday)}, ${_twoDigits(_now.day)} ${_monthName(_now.month)} ${_now.year}";

  // NEW: Add this getter
  String get currentTime => "$hours:$minutes:$seconds";

  ClockProvider() {
    _now = DateTime.now();
    _updateTime();
    // Start the timer to periodically update the time
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _updateTime(),
    );
  }

  void _updateTime() {
    _now = DateTime.now();
    // Notify all listeners (the UI widgets) that the data has changed
    notifyListeners();
  }

  // --- Helper Methods (Business Logic) ---
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _monthName(int month) {
    const months = [
      '',
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[month];
  }

  String _weekDay(int weekday) {
    const days = ['', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[weekday];
  }

  // Remember to dispose of the timer to prevent memory leaks
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
