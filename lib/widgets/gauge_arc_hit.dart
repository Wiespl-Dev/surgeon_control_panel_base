import 'dart:math' as math;
import 'dart:ui';

/// Touch hit-testing for the 150° → 30° (240° sweep) SfRadialGauge arcs used
/// by the temperature and humidity screens. Assumes the gauge fills [size]
/// with the default RadialAxis centre (0.5, 0.5) and radiusFactor (0.95).
class GaugeArcHit {
  static const double _startDeg = 150;
  static const double _sweepDeg = 240;
  static const double _radiusFactor = 0.95; // RadialAxis default
  static const double _thicknessFactor = 0.15; // axisLineStyle thickness
  static const double _touchSlop = 24; // extra px of grab area around the bar

  /// True if [pos] is on the bar (or within a finger's width of it) — not
  /// the centre readout, the empty corners, or the open gap at the bottom.
  static bool isOnArc(Offset pos, Size size) {
    final v = pos - size.center(Offset.zero);
    final outer = size.shortestSide / 2 * _radiusFactor;
    final inner = outer * (1 - _thicknessFactor);
    final d = v.distance;
    if (d < inner - _touchSlop || d > outer + _touchSlop) return false;
    return _relDeg(v) <= _sweepDeg;
  }

  /// 0.0 (start of the bar) … 1.0 (end). Positions in the bottom gap snap to
  /// the nearer end, so dragging past an end doesn't jump to the other one.
  static double fraction(Offset pos, Size size) {
    final rel = _relDeg(pos - size.center(Offset.zero));
    if (rel <= _sweepDeg) return rel / _sweepDeg;
    return rel < _sweepDeg + (360 - _sweepDeg) / 2 ? 1.0 : 0.0;
  }

  /// Clockwise degrees from the start of the bar, in [0, 360).
  static double _relDeg(Offset v) {
    final deg = v.direction * 180 / math.pi; // screen coords: clockwise
    return (deg - _startDeg) % 360; // Dart's % is always non-negative
  }
}
