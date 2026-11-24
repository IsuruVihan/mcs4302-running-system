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
    // TODO 1a (about 10 lines)
    // 1. If `await Geolocator.isLocationServiceEnabled()` is false, throw
    //    LocationException('Location is switched off on the emulator. Turn it on in Settings > Location.')
    // 2. var permission = await Geolocator.checkPermission();
    //    If it is LocationPermission.denied, ask the user:
    //    permission = await Geolocator.requestPermission();
    // 3. If permission is still LocationPermission.denied, or is
    //    LocationPermission.deniedForever, throw a LocationException that says so.
    // Ask only for foreground location: the lab tracks only while the app is open.
    throw UnimplementedError('TODO 1a: ensurePermission');
  }

  /// A stream of fixes, asking for one every [intervalS] seconds.
  Stream<Position> positions(int intervalS) {
    // TODO 1b (about 6 lines)
    // 1. Build the settings: AndroidSettings(
    //        accuracy: LocationAccuracy.high,
    //        distanceFilter: 0,          // no distance filter: compare intervals only
    //        intervalDuration: Duration(seconds: intervalS))
    // 2. Return Geolocator.getPositionStream(locationSettings: settings).
    // The interval is only a REQUEST: the measurement panel shows what arrives.
    throw UnimplementedError('TODO 1b: positions');
  }
}
