# 0001: Port the API client to Dart

Status: accepted, 2026-11-14

## Context

`soundcloud-v2` (crates.io 0.2.0) is the measured, working client for the
catalogue in `../soundcloud-protocol`. It resolves the client id, refreshes it
after a 401, paginates, and selects a transcoding. It is about a thousand lines
of Rust including tests.

The app needs that client on Android and iOS. Flutter can call Rust through
`flutter_rust_bridge`, with `cargo-ndk` for Android and an xcframework for iOS.

Development happens on Windows. iOS can only be compiled by the CI workflow on
macOS. Anything that touches the iOS native build cannot be run locally.

## Decision

Port the client to Dart. Keep `soundcloud-v2` as the reference implementation
and do not link it into the app.

The port is plain HTTP plus JSON: discovery reads one HTML page, scans its
script assets for `client_id:"<32 characters>"`, then every API call adds the
id, retries once after a 401, and follows `next_href`. The measured routes and
their response shapes are already written down.

## Consequences

- One language and one build for both platforms. There is no NDK, no
  xcframework, no generated bridge, and no second toolchain to debug blind on
  macOS.
- The client is re-implemented and can drift from the crate. The crate's tests
  and the catalogue examples are the check; the Dart client has its own tests
  for discovery, refresh, pagination and rendition order.
- If a future route needs more than HTTP and JSON, such as the licence exchange
  for encrypted HLS, the decision has to be revisited. That is out of scope
  today.
