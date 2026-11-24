import 'dart:convert';

import 'config.dart';
import 'geo_event.dart';

/// One detected event, as shown on screen.
class EventRecord {
  const EventRecord({
    required this.type,
    required this.fixNo,
    required this.trueDistanceM,
    required this.real,
    required this.queuedOffline,
    this.queueError,
  });

  final String type; // 'enter' or 'exit'
  final int fixNo; // which fix triggered it
  final double trueDistanceM; // real distance to the centre at that fix

  /// False when the user had not really crossed (a bad fix triggered it).
  final bool real;
  final bool queuedOffline;

  /// Set when the event could not be saved in the queue (it was detected
  /// but will never be sent).
  final String? queueError;

  /// ESTIMATED seconds between the true crossing and the detection.
  ///
  /// The GPX route walks a straight line at a constant 2 m/s, so the distance
  /// already walked past the boundary, divided by 2 m/s, is the time since the
  /// crossing. This assumes the emulator follows the route exactly at 1X.
  double? get delayS {
    if (!real) return null;
    final past = type == 'enter'
        ? kFenceRadiusM - trueDistanceM
        : trueDistanceM - kFenceRadiusM;
    return past / kWalkSpeedMps;
  }

  @override
  String toString() {
    final what = real
        ? '${type.toUpperCase()} · estimated delay ${delayS!.toStringAsFixed(1)} s'
        : 'FALSE ${type.toUpperCase()} (really ${trueDistanceM.toStringAsFixed(0)} m from centre)';
    final q = queueError != null
        ? ' · NOT QUEUED ($queueError)'
        : (queuedOffline ? ' · queued offline' : '');
    return '$what · fix #$fixNo$q';
  }
}

/// Everything the measurement sheet needs for one run. You do not need to
/// change this file.
class RunMetrics {
  int updates = 0;
  DateTime? first;
  DateTime? last;
  final List<double> gapsS = [];

  /// Bytes the location trace WOULD cost if every fix were uploaded as JSON
  /// (the "send every coordinate" design the lab avoids).
  int locationBytes = 0;

  final List<EventRecord> events = [];

  void onFix(Fix f) {
    updates++;
    if (last != null) {
      gapsS.add(f.receivedAt.difference(last!).inMilliseconds / 1000);
    }
    first ??= f.receivedAt;
    last = f.receivedAt;
    locationBytes += fixPayloadBytes(f);
  }

  /// Mean time between fixes that actually arrived (seconds).
  double? get meanIntervalS =>
      gapsS.isEmpty ? null : gapsS.reduce((a, b) => a + b) / gapsS.length;

  /// Time from the first to the last fix (seconds).
  double get durationS => (first == null || last == null)
      ? 0
      : last!.difference(first!).inMilliseconds / 1000;

  double? delayOf(String type) {
    for (final e in events) {
      if (e.type == type && e.delayS != null) return e.delayS;
    }
    return null;
  }

  /// Was the user really inside before this fix? (Used to tell a real exit
  /// from a false one: a real exit needs a real enter first.)
  bool get hadRealEnter => events.any((e) => e.real && e.type == 'enter') &&
      !events.any((e) => e.real && e.type == 'exit');

  /// Size of one fix as a naive upload (same shape as lecture slide 21).
  static int fixPayloadBytes(Fix f) => utf8
      .encode(jsonEncode({
        'user': 'u42',
        'lat': f.lat,
        'lng': f.lng,
        'accuracy_m': f.accuracyM,
        'time': f.receivedAt.toUtc().toIso8601String(),
      }))
      .length;
}
