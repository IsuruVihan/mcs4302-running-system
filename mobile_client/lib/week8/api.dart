import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'geo_event.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => 'ApiException: $message';
}

/// Week 8 endpoints under /w8. You do not need to change this file.
class Api {
  Api({this.baseUrl = kBaseUrl});

  final String baseUrl;
  final http.Client _client = http.Client();
  static const _timeout = Duration(seconds: 5);

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Map<String, dynamic> _json(http.Response r) {
    if (r.statusCode >= 400) {
      throw ApiException('${r.request?.url.path} -> HTTP ${r.statusCode}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Send one event. Retries 5xx and network errors with exponential backoff
  /// (Week 4), always with the SAME idempotency key (Week 7), so a retry can
  /// never store the event twice.
  Future<void> postEvent(GeoEvent e) async {
    for (var attempt = 0;; attempt++) {
      try {
        final r = await _client
            .post(_u('/events'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(e.toJson()))
            .timeout(_timeout);
        if (r.statusCode == 200) return;
        if (r.statusCode < 500) {
          throw ApiException('/events -> HTTP ${r.statusCode}: ${r.body}');
        }
      } on TimeoutException {
        // retry
      } on SocketException {
        // retry
      } on http.ClientException {
        // retry
      }
      if (attempt >= 3) {
        throw ApiException('/events failed after ${attempt + 1} tries');
      }
      await Future<void>.delayed(Duration(milliseconds: 300 * (1 << attempt)));
    }
  }

  /// Start of a run: clear the server's events and byte counters.
  Future<void> reset() async {
    _json(await _client
        .post(_u('/reset'),
            headers: {'Content-Type': 'application/json'}, body: '{}')
        .timeout(_timeout));
  }

  /// Request body bytes and calls for POST /w8/events since the last reset.
  Future<(int calls, int bytes)> eventTraffic() async {
    final j = _json(await _client.get(_u('/stats')).timeout(_timeout));
    final e = (j['endpoints'] as Map<String, dynamic>)['POST /w8/events']
        as Map<String, dynamic>?;
    if (e == null) return (0, 0);
    return (e['calls'] as int, e['req_bytes'] as int);
  }
}
