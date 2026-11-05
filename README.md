# MCS4302 Mobile Computing - running system (index 24440329)

Flutter client (`mobile_client/`) for a FastAPI backend (`backend/`), started in
the Week 4 lab and kept for Weeks 5, 6, 7, 9 and 10.

## Backend (host)

```
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1        # Windows PowerShell
python -m pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Swagger: http://localhost:8000/docs

## Flutter client (Android Emulator)

```
cd mobile_client
flutter pub get
flutter run
```

The emulator reaches the host at `http://10.0.2.2:8000` (`lib/config.dart`).
Plain HTTP is allowed in `AndroidManifest.xml` for this local lab only and is
removed when HTTPS is enabled in Week 9.

## Week 4 results

Raw output of the Part 5 retry experiment (seeds 42, 43, 44) is in
`measurements/week4_retry_experiment.csv`, one row per condition per run, as
copied from the app's **Copy CSV** button.

Note: `lib/main.dart` uses `setState(() { _future = api.getItems(); })` rather
than the code pack's arrow form `setState(() => _future = ...)`. The arrow
closure returns the Future, which fails a debug assertion in `setState` and
skips the rebuild, so the refresh button never updated the screen.

## Week 6 results

Entry point: `flutter run -t lib/main_week6.dart` (add `--profile` for Part 3).
Tests: `flutter test` (8 tests; the Week 6 ones use fakes, no backend needed).

- Part 2 seeded bug: `setState() called after dispose()` at
  `lib/week6/detail_page.dart:34`. `_load()` awaited a 3 s detail request and
  then called `setState` after Back had disposed the page. Fixed with
  `if (!mounted) return;` before `setState`.
- Part 3: the 12 measured runs (profile mode, Android emulator) are in
  `measurements/week6_isolate_experiment.csv`, in run order, as printed in the
  `W6RUN` console lines. Isolate.run cut the worst frame at n = 50k from about
  143 ms to 43 ms but did not shorten end-to-end time; at n = 5k it made the
  decode slower (13 ms to 40 ms).

## Week 7 results

Entry point: `flutter run -t lib/main_week7.dart` (Phone A). The backend's
`/w7` endpoints come from `backend/week7.py`.

- TODO 1 (`lib/week7/local_db.dart`): `editTask` updates the task row and
  inserts its outbox row in one transaction. After an offline edit and
  `adb shell am force-stop`, the outbox (1 row), the pending task-42 and the
  Offline switch all survived the restart.
- TODO 2 (`lib/week7/sync_engine.dart`): on a 409 the op is merged only if the
  server did not change the same field; otherwise it is blocked and task-42
  is flagged `conflict`.
- All runs (record 42 scenarios S1-S3, LWW vs version, and the Part 3 lost
  reply) are in `measurements/week7_sync_runs.csv`, copied from the app's
  Last sync card and the server copy of task-42.
