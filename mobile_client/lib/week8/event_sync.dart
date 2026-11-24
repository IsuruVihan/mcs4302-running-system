import 'api.dart';
import 'event_queue.dart';

/// Sends queued events to the server, oldest first. You do not need to
/// change this file.
///
/// Same rules as the Week 7 sync engine: an event leaves the queue only after
/// the server answered OK, and nothing is sent while the app is offline.
class EventSync {
  EventSync(this.queue, this.api);

  final EventQueue queue;
  final Api api;
  bool online = true;
  bool _running = false;

  /// Returns the number of events sent. Throws if the server cannot be reached
  /// (the events stay queued and are sent on the next sync).
  Future<int> syncNow() async {
    if (!online || _running) return 0;
    _running = true;
    var sent = 0;
    try {
      // Loop until empty: events detected during a sync are sent too.
      while (online) {
        final batch = await queue.pending();
        if (batch.isEmpty) break;
        for (final e in batch) {
          if (!online) break;
          await api.postEvent(e);
          await queue.remove(e.seq);
          sent++;
        }
      }
      return sent;
    } finally {
      _running = false;
    }
  }
}
