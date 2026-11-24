/// One location fix as the geofence sees it.
///
/// The page builds it from a geolocator Position. [trueDistanceM] is the
/// distance to the fence centre, used by the measurement panel to work out
/// the detection delay.
class Fix {
  const Fix({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.receivedAt,
    required this.trueDistanceM,
  });

  final double lat;
  final double lng;

  /// Radius of uncertainty reported with the fix (metres).
  final double accuracyM;

  /// When the app received the fix (used for the actual interval).
  final DateTime receivedAt;

  /// Distance to the fence centre (for the measurement panel only).
  final double trueDistanceM;
}

/// One queued geofence event (a row of the event_outbox table).
///
/// Only these four fields leave the phone: the event, not the location trace
/// (lecture slides 29 and 30).
class GeoEvent {
  const GeoEvent({
    required this.seq,
    required this.idemKey,
    required this.fenceId,
    required this.type,
    required this.at,
  });

  final int seq;
  final String idemKey;
  final String fenceId;
  final String type; // 'enter' or 'exit'
  final String at; // device time, ISO 8601 UTC

  Map<String, Object?> toJson() => {
        'idem_key': idemKey,
        'fence_id': fenceId,
        'type': type,
        'at': at,
      };

  factory GeoEvent.fromDb(Map<String, Object?> r) => GeoEvent(
        seq: r['seq'] as int,
        idemKey: r['idem_key'] as String,
        fenceId: r['fence_id'] as String,
        type: r['type'] as String,
        at: r['at'] as String,
      );
}
