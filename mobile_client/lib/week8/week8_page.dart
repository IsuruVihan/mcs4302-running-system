import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'api.dart';
import 'config.dart';
import 'event_queue.dart';
import 'event_sync.dart';
import 'geo_event.dart';
import 'geofence.dart';
import 'location_service.dart';
import 'run_metrics.dart';

/// Everything the lab needs is on this one screen. You do not need to change
/// this file.
class Week8Page extends StatefulWidget {
  const Week8Page({super.key});

  @override
  State<Week8Page> createState() => _Week8PageState();
}

class _Week8PageState extends State<Week8Page> {
  final Api api = Api();
  final LocationService location = LocationService();
  final GeofenceMonitor fence = GeofenceMonitor();
  EventQueue? queue;
  EventSync? sync;

  StreamSubscription<Position>? _sub;

  /// Ends the run when the GPX route ends, even if no fix arrives at the end
  /// point (a 30 s interval may give its last fix well before the end).
  Timer? _endTimer;
  bool running = false;
  bool online = true;
  int intervalS = kIntervalsS.first;

  RunMetrics metrics = RunMetrics();
  Fix? lastFix;
  int queued = 0;
  int eventCalls = 0;
  int eventBytes = 0;
  String? message;

  // Route gating: a run counts only fixes from the GPX route, which starts
  // 200 m WEST of the centre and ends 200 m EAST of it.
  bool _onRoute = false;
  int ignored = 0;

  /// Distance of the last waiting fix at the route's west end. The route counts
  /// as started only when a later fix has MOVED at least 1 m towards the
  /// centre, so an emulator already parked at the start point (before Play)
  /// does not start the run.
  double? _armD;
  Position? _armPos;
  DateTime? _armAt;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _endTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final q = await EventQueue.open();
      queue = q;
      online = await q.online();
      sync = EventSync(q, api)..online = online;
      await _refreshQueue();
    } catch (e) {
      message = 'Start-up failed: $e';
    }
    if (mounted) setState(() {});
  }

  Future<void> _refreshQueue() async {
    queued = await queue!.count();
  }

  // ------------------------------------------------------------ run control

  Future<bool> _confirmDiscard(int n) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsent events'),
          content: Text('$n event(s) have not reached the server yet. '
              'A new run empties the queue and they will be lost.\n\n'
              'To keep them, cancel, go Online and wait until the queue is 0.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Discard and start')),
          ],
        ),
      ) ??
      false;

  Future<void> _startRun() async {
    await _refreshQueue();
    if (queued > 0 && !await _confirmDiscard(queued)) {
      setState(() {});
      return;
    }
    _endTimer?.cancel();
    _endTimer = null;
    await _sub?.cancel();
    _sub = null;
    setState(() => message = null);
    try {
      await location.ensurePermission(); // TODO 1a
    } catch (e) {
      setState(() => message = '$e');
      return;
    }
    try {
      await api.reset();
    } catch (e) {
      message = 'Backend not reachable ($e). Events will queue until it is.';
    }
    await queue!.clear();
    metrics = RunMetrics();
    fence.reset();
    lastFix = null;
    eventCalls = 0;
    eventBytes = 0;
    _onRoute = false;
    ignored = 0;
    _armD = null;
    _armPos = null;
    _armAt = null;
    await _refreshQueue();

    try {
      _sub = location.positions(intervalS).listen( // TODO 1b
            _onPosition,
            onError: (Object e) {
              if (mounted) setState(() => message = 'Location error: $e');
            },
          );
    } catch (e) {
      setState(() => message = '$e');
      return;
    }
    setState(() {
      running = true;
      message ??= 'Run started (interval $intervalS s). Now press Play on the GPX route.';
    });
  }

  Future<void> _stopRun() async {
    _endTimer?.cancel();
    _endTimer = null;
    await _sub?.cancel();
    _sub = null;
    setState(() => running = false);
    await _sync();
    await _loadTraffic();
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------ each fix

  Fix _toFix(Position p, double trueD, DateTime at) => Fix(
        lat: p.latitude,
        lng: p.longitude,
        accuracyM: p.accuracy,
        receivedAt: at,
        trueDistanceM: trueD,
      );

  Future<void> _onPosition(Position p) async {
    if (!running) return;
    final now = DateTime.now();
    final trueD =
        Geolocator.distanceBetween(p.latitude, p.longitude, kFenceLat, kFenceLng);
    final west = p.longitude < kFenceLng;

    // Wait until the walk has started: a fix at the west end (within 205 m)
    // that has MOVED at least 1 m towards the centre since the previous fix.
    // An emulator parked at the start point before Play does not count.
    if (!_onRoute) {
      final atWestEnd = west && trueD <= 205;
      final moving = atWestEnd && _armD != null && _armD! - trueD >= 1.0;
      if (!moving) {
        _armPos = atWestEnd ? p : null;
        _armD = atWestEnd ? trueD : null;
        _armAt = now;
        ignored++;
        message = 'Waiting for the walk to start: press Play on the GPX route '
            '($ignored fixes ignored so far).';
        if (mounted) setState(() {});
        return;
      }
      _onRoute = true;
      message = 'On the route: measuring.';

      // The waiting fix was already part of the walk unless it was at the
      // start point, so count it too (at 30 s it may be the only fix before
      // the enter).
      final keepArmed = _armD! < 199;
      final startD = keepArmed ? _armD! : trueD;
      final startAt = keepArmed ? _armAt! : now;

      // Route time of the first counted fix: the walk starts 200 m west at
      // t = 0 s and ends 200 m east at t = 200 s. Stop 5 s after the end.
      final routeTimeS = (200 - startD) / kWalkSpeedMps;
      final leftMs = ((200 - routeTimeS + 5) * 1000).round() -
          now.difference(startAt).inMilliseconds;
      _endTimer = Timer(Duration(milliseconds: leftMs < 0 ? 0 : leftMs), () {
        if (!running) return;
        message = 'End of the route: run stopped. Copy the numbers below.';
        _stopRun();
      });

      if (keepArmed) {
        ignored--;
        await _process(_toFix(_armPos!, _armD!, _armAt!));
      }
    }

    await _process(_toFix(p, trueD, now));

    // The route ends 200 m east of the centre: stop the run there.
    if (running && !west && trueD >= 199) {
      message = 'End of the route: run stopped. Copy the numbers below.';
      await _stopRun();
      return;
    }
    if (mounted) setState(() {});
  }

  /// One counted fix: measurement panel, geofence (TODO 2), queue (TODO 3).
  Future<void> _process(Fix fix) async {
    metrics.onFix(fix);
    lastFix = fix;

    String? type;
    try {
      type = fence.onFix(fix); // TODO 2
    } catch (e) {
      message = '$e';
    }
    if (type == null) return;

    final real = type == 'enter'
        ? fix.trueDistanceM < kFenceRadiusM
        : fix.trueDistanceM >= kFenceRadiusM && metrics.hadRealEnter;
    String? queueError;
    try {
      await queue!.add(type); // TODO 3
    } catch (e) {
      queueError = '$e';
      message = 'Event detected but NOT queued: $e';
    }
    metrics.events.add(EventRecord(
      type: type,
      fixNo: metrics.updates,
      trueDistanceM: fix.trueDistanceM,
      real: real,
      queuedOffline: !online,
      queueError: queueError,
    ));
    await _refreshQueue();
    unawaited(_sync());
  }

  // ------------------------------------------------------------ sync

  Future<void> _sync() async {
    if (sync == null || !online) return;
    try {
      await sync!.syncNow();
    } catch (e) {
      message = 'Sync failed, events stay queued: $e';
    }
    await _refreshQueue();
    if (mounted) setState(() {});
  }

  Future<void> _loadTraffic() async {
    try {
      final (calls, bytes) = await api.eventTraffic();
      eventCalls = calls;
      eventBytes = bytes;
    } catch (_) {
      // backend down: keep the old numbers
    }
  }

  Future<void> _toggleOnline(bool v) async {
    online = v;
    sync!.online = v;
    await queue!.setOnline(v);
    setState(() {});
    if (v) {
      await _sync(); // sync trigger: back online
      await _loadTraffic();
      if (mounted) setState(() {});
    }
  }

  // ------------------------------------------------------------ UI

  String _f(double? v, [int digits = 1]) => v == null ? '–' : v.toStringAsFixed(digits);

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final inside = fence.inside;
    final stateText = inside == null ? 'unknown' : (inside ? 'INSIDE' : 'outside');
    final stateColor = inside == null
        ? Colors.grey
        : (inside ? Colors.green : Colors.blueGrey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Week 8 · Geofence'),
        actions: [
          Text(online ? 'Online' : 'Offline'),
          Switch(value: online, onChanged: sync == null ? null : _toggleOnline),
        ],
      ),
      body: queue == null
          ? Center(child: Text(message ?? 'Opening database…'))
          : ListView(padding: const EdgeInsets.all(12), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Run settings',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Requested update interval'),
                    SegmentedButton<int>(
                      segments: [
                        for (final s in kIntervalsS)
                          ButtonSegment(value: s, label: Text('$s s')),
                      ],
                      selected: {intervalS},
                      onSelectionChanged: running
                          ? null
                          : (v) => setState(() => intervalS = v.first),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      FilledButton(
                          onPressed: running ? null : _startRun,
                          child: const Text('Start run')),
                      OutlinedButton(
                          onPressed: running ? _stopRun : null,
                          child: const Text('Stop run')),
                    ]),
                  ]),
                ),
              ),
              if (message != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(message!)),
              Card(
                color: stateColor.withOpacity(0.12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Geofence: $stateText',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold, color: stateColor)),
                    _row('Distance to centre (as the app sees it)',
                        '${_f(fence.lastDistanceM, 0)} m'),
                    _row('Reported accuracy',
                        '±${_f(lastFix?.accuracyM, 0)} m'),
                    _row('Events waiting in the queue', '$queued'),
                  ]),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Measurement sheet · interval $intervalS s',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    _row('Location updates received', '${metrics.updates}'),
                    _row('Run duration (first to last fix)', '${_f(metrics.durationS)} s'),
                    _row('Mean actual interval', '${_f(metrics.meanIntervalS, 2)} s'),
                    _row('Location-update bytes (estimated, if every fix were sent)',
                        '${metrics.locationBytes} B'),
                    _row('Geofence event bytes (actual request bodies)',
                        '$eventBytes B in $eventCalls calls'),
                    _row('Detection delay, enter (estimated)',
                        '${_f(metrics.delayOf('enter'))} s'),
                    _row('Detection delay, exit (estimated)',
                        '${_f(metrics.delayOf('exit'))} s'),
                    const SizedBox(height: 4),
                    const Text('Event bytes update when you stop the run or go back online.',
                        style: TextStyle(fontSize: 12)),
                  ]),
                ),
              ),
              if (metrics.events.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Events this run',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      for (final e in metrics.events) Text(e.toString()),
                    ]),
                  ),
                ),
            ]),
    );
  }
}
