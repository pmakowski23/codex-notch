# Codex Usage

Codex Usage is a small macOS menu bar and notch-style monitor for local Codex usage. It watches the Codex session rollout logs, reads token usage from `token_count` events, and shows the current 5-hour and 7-day usage windows without sending data to a remote service.

The app is built as a Swift Package and is split into a reusable `CodexUsageKit` library plus the `CodexUsageApp` macOS executable.

## Features

- Live monitoring of Codex rollout JSONL files under `~/.codex/sessions`.
- Compact menu bar indicator that updates to the highest active usage percentage.
- Notch-style floating panel with 5-hour and 7-day usage rings.
- Token breakdown by project and model from the local Codex state database.
- Notification rules for under-used windows near reset and low projected burn rate.
- Local settings persisted with `UserDefaults`.
- Read-only access to Codex state data; the app does not mutate Codex files.

## Requirements

- macOS 14 or newer.
- Swift 6 toolchain.
- A local Codex installation that writes session rollout logs to `~/.codex/sessions`.
- Optional: a local Codex state database at `~/.codex/state_5.sqlite` for project/model breakdowns.

## Quick Start

Build the package:

```sh
swift build
```

Run the app during development:

```sh
swift run CodexUsageApp
```

Run the test suite:

```sh
swift test
```

When launched with `swift run`, the app starts as an accessory-style macOS process and shows the floating usage panel. Notification delivery is intentionally guarded so it only fires from a packaged `.app` bundle.

## Release Builds

Create a versioned `.app` bundle and zip archive:

```sh
Scripts/build-app.sh --version 0.1.0
```

If `--build` is omitted, the script uses the current timestamp as `CFBundleVersion` so each build is monotonic.

The script writes build artifacts to `dist/`:

```text
dist/
  Codex Usage.app
  CodexUsage-0.1.0.zip
```

Install the freshly built app into `/Applications`:

```sh
Scripts/build-app.sh --version 0.1.0 --install
```

By default, the app is ad-hoc signed for local use. To create a Developer ID signed build, pass a signing identity:

```sh
Scripts/build-app.sh \
  --version 0.1.0 \
  --build 12 \
  --sign "Developer ID Application: Example, Inc. (TEAMID)"
```

For public distribution outside your Mac, notarize the resulting archive with Apple after signing it with a Developer ID certificate.

## How It Works

Codex Usage combines two local data sources:

1. Session rollout logs under `~/.codex/sessions`.
   `RolloutWatcher` follows the newest `rollout-*.jsonl` file and passes new lines to `RolloutParser`. The parser extracts `event_msg` entries whose payload type is `token_count`.

2. Codex state database at `~/.codex/state_5.sqlite`.
   `TasksRepository` opens the database in read-only mode through GRDB and summarizes recent token use by project path and model.

Parsed usage events are stored in `UsageStore`, which keeps the latest rate-limit state and a short sample history for burn-rate projections. The SwiftUI views observe that store to update the menu bar title, compact notch panel, expanded usage rings, and task breakdown.

## Configuration

The default settings are defined in `AppSettings`:

| Setting | Default | Purpose |
| --- | --- | --- |
| `sessionsRootPath` | `~/.codex/sessions` | Directory containing Codex session rollout JSONL files. |
| `stateDatabasePath` | `~/.codex/state_5.sqlite` | Local Codex state database used for task breakdowns. |
| `notifyMinutesBeforeReset` | `60` | Warn when a usage window is close to reset. |
| `notifyUsedBelowPercent` | `60` | Only send reset reminders while usage is below this percentage. |
| `burnRateProjectionBelowPercent` | `70` | Warn when projected usage at reset remains below this percentage. |

Settings are saved in `UserDefaults` under the key `app.codexusage.settings`.

## Project Layout

```text
Package.swift
Sources/
  CodexUsageApp/
    AppMain.swift              # macOS app entry point and wiring
    MenuBarController.swift    # NSStatusItem integration
    NotchPanel.swift           # Floating notch-style panel and settings modal
    Views/                     # SwiftUI usage and breakdown views
  CodexUsageKit/
    Notifications/             # Notification rule evaluation and scheduling
    Rollout/                   # JSONL watcher, parser, and rollout models
    Settings/                  # Codable app settings and persistence
    Tasks/                     # Read-only task breakdown queries
    Usage/                     # Usage store and burn-rate projection logic
Tests/
  CodexUsageKitTests/
  SmokeTests/
```

## Testing

The tests use Swift Testing and local fixtures. Current coverage focuses on:

- Parsing representative Codex `token_count` rollout events.
- Evaluating notification decisions.
- Reading appended rollout lines through the watcher smoke test.

Run all tests with:

```sh
swift test
```

## Troubleshooting

If the app shows "Waiting for data", confirm that Codex has created rollout files under `~/.codex/sessions` and that a recent file contains `token_count` events.

If project/model breakdowns are empty, confirm that `~/.codex/state_5.sqlite` exists and contains recent rows with token usage. The app opens this database read-only; missing or incompatible databases simply disable breakdown data.

If notifications do not appear while using `swift run`, package and run the app as a `.app` bundle. The notification scheduler skips delivery outside an app bundle so command-line development runs do not trigger system notifications unexpectedly.

## Development Notes

- `CodexUsageKit` owns parsing, state, settings, notifications, and database access.
- `CodexUsageApp` owns AppKit and SwiftUI presentation.
- `RolloutWatcher` uses macOS file-system events and falls back to scanning the latest rollout file when events arrive.
- `TasksRepository` uses GRDB with a read-only `DatabaseQueue`.
- The app prefers local-first behavior and does not require network access at runtime.
