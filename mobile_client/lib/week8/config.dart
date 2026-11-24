// 10.0.2.2 is the host machine as seen from the Android Emulator (Week 4).
// Use your laptop's LAN IP instead if you run on a physical phone.
const String kBaseUrl = 'http://10.0.2.2:8000/w8';

// The geofence (lecture slides 14 and 30): a 100 m circle at the campus gate.
const String kFenceId = 'campus-gate';
const double kFenceLat = 6.9022;
const double kFenceLng = 79.8612;
const double kFenceRadiusM = 100;

// The shared GPX route walks straight through the centre at this speed:
// 400 m in 200 s, so the true crossings are at t = 50 s (enter) and t = 150 s (exit).
const double kWalkSpeedMps = 2.0;

// Requested update intervals for the three measured runs (lecture slide 32).
const List<int> kIntervalsS = [1, 5, 30];
