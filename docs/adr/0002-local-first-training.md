# 0002: Local-first strength training alongside the player

Status: accepted, 2026-11-14

## Context

altaria is already one Flutter app with a working SoundCloud client and a single
`AudioService`. The product now needs a strength tracker that reaches functional
parity with a phone-based logging app while keeping original UI, copy and assets.

Training has different constraints from music:

- it must work on a fresh install in airplane mode;
- it must not require an account, network, purchase or setup;
- it must persist across force-stops;
- it must coexist with lock-screen playback without owning audio;
- it must be exportable without a server.

At the same time, the request explicitly rejects a second app, a second music
player, and a rewrite of the git history.

## Decision

### One shell, two modes

Extend `HomeShell` rather than fork the app. Listen keeps Search/Browse; Train
owns Workout/Routines/History/Progress. The chosen mode is stored with the
training settings. The mini player and full player stay in the existing music
path. Training screens are ordinary routes pushed above the shell.

### SQLite behind a repository

Use local SQLite through `sqflite` on both mobile platforms, with a versioned
migration list and `schema_migrations` table. All writes go through
`TrainingRepository`. A single `TrainingStore` coordinates refresh and exposes
the data to widgets.

The exercise catalogue is original seed data with common movement names and
short cues written for altaria. It is inserted with conflict-ignore semantics in
one batch, so every launch can safely call the same seed path. The schema also
stores custom movements, archived movements, routines and targets, workout
sessions, set-level detail, body metrics, photos and settings.

Keeping the training store local means no server, login, sync, analytics or API
for the gym. It also makes import/export a transaction rather than a merge
policy.

### One player, no second audio session

Training never creates an `AudioPlayer`, an `AudioSession`, or an
`AudioService`. The existing `AltariaAudioHandler` remains the only media
session. Rest feedback uses a notification on a dedicated channel and haptic
feedback from the UI. It does not request audio focus.

The timer lives in the app and posts its notification when it reaches zero,
which gives exact feedback while the process is alive. A scheduled inexact
notification is installed as a fallback for process death. The app deliberately
avoids the exact-alarm permission; timer accuracy in the background may depend on
Android's scheduling, but music is never interrupted. Denied notification
permission disables the system alert only; the countdown continues.

### Local backup over sync

A full JSON backup includes every training table and settings. Progress photos
are embedded as base64 because they live in SQLite as blobs. CSV is a
finished-workout export. Both use the system share sheet through `share_plus`.
Import replaces training data in one SQLite transaction after validation.

This is intentionally not a sync protocol. There is no conflict resolution,
account or remote copy to recover.

### Cross-platform plugins

Chosen plugins support both Android and iOS: `sqflite`, `flutter_local_notifications`,
`share_plus`, `file_picker`, `wakelock_plus`, `path_provider` and `timezone`.
Android has notification permission/receivers and core-library desugaring. iOS
has the notification delegate and no new photo-library permission because
`file_picker` uses the document picker. The iOS build is exercised in CI, not on
the Windows development machine.

## Consequences

- Music remains a separate, stable module. A training bug cannot replace the
  media session, and a mode switch cannot stop playback.
- Training is fully usable offline and survives process restarts.
- The app owns the schema and must ship forward migrations for every future
  table change.
- Import is destructive by design; the UI asks for confirmation first.
- Rest alerts can be late if Android kills the process and batches the scheduled
  inexact alarm. While the app runs, the timer posts its own alert.
- The 200-movement seed is part of the repository, not downloaded.
- iOS compilation still needs CI or a Mac; local Android verification cannot
  prove the iOS native build.

## Deliberate cuts

Apple Watch, Wear OS, HealthKit, Health Connect, widgets, Live Activities and
cloud sync are out of scope. Offline music and user-token login remain out;
music scope is unchanged. No purchase prompt, IAP, trial or account exists.
