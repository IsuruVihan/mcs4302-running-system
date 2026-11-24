import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Wraps geolocator: permission and the position stream.  YOU COMPLETE THIS FILE (TODO 1).
class LocationService {
  /// Make sure location is switched on and the app may use it.
  Future<void> ensurePermission() async {
    // TODO 1a: location switched on, then foreground permission (ask only if denied).
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException(
          'Location is switched off on the emulator. Turn it on in Settings > Location.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException('Location permission denied permanently. Allow it in '
          'Settings > Apps > mobile_client > Permissions > Location, then Start run again.');
    }
    if (permission == LocationPermission.denied) {
      throw LocationException('Location permission denied: the geofence needs it.');
    }
  }

  /// A stream of fixes, asking for one every [intervalS] seconds.
  Stream<Position> positions(int intervalS) {
    // TODO 1b: ask for one fix every intervalS seconds, with no distance filter.
    // The interval is only a REQUEST: the measurement panel shows what arrives.
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // no distance filter: compare intervals only
      intervalDuration: Duration(seconds: intervalS),
    );
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}
