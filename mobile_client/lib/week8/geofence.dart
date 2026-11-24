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

    // TODO 2 (about 8 lines). `d` is already computed above.
    // 1. This fix is inside if d < kFenceRadiusM.
    // 2. If `inside` is still null (the first fix of the run), set it and
    //    return null: the first fix sets the state but is not an event.
    // 3. If the state did not change, return null.
    // 4. Otherwise update `inside` and return 'enter' or 'exit'.
    throw UnimplementedError('TODO 2: onFix');
  }
}
