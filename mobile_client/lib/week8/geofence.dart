import 'package:geolocator/geolocator.dart';

import 'config.dart';
import 'geo_event.dart';

/// App-level geofence: a distance check on every fix (lecture slide 25).
/// YOU COMPLETE onFix (TODO 2).
class GeofenceMonitor {
  /// Current state: true = inside, false = outside, null = not known yet.
  bool? inside;

  /// Distance from the last fix to the centre, as the app saw it (metres).
  double? lastDistanceM;

  void reset() {
    inside = null;
    lastDistanceM = null;
  }

  /// Called for every fix. Returns 'enter' or 'exit' when the state changes,
  /// otherwise null.
  String? onFix(Fix fix) {
    final d = Geolocator.distanceBetween(fix.lat, fix.lng, kFenceLat, kFenceLng);
    lastDistanceM = d;

    // TODO 2: an event only when the inside/outside state changes.
    final nowInside = d < kFenceRadiusM;
    if (inside == null) {
      inside = nowInside; // first fix: sets the state, is not an event
      return null;
    }
    if (nowInside == inside) return null;
    inside = nowInside;
    return nowInside ? 'enter' : 'exit';
  }
}
