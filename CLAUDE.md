# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter + Dart CLI experiment demonstrating process lifecycle independence. The core goal is to prove that a Dart binary daemon can survive independently after the parent Flutter app terminates.

**Architecture**: Two separate processes
- **Flutter macOS App** (`lib/`): UI controller for managing the daemon
- **Dart CLI Daemon** (`bin/daemon.dart`): Independent background process that logs heartbeats every 1 second

## Critical Build Steps

### 1. Compile the Daemon Binary (Required First)

```bash
dart compile exe bin/daemon.dart -o bin_output/daemon
```

This must be done before running the Flutter app, as the app expects the binary to exist at `bin_output/daemon`.

### 2. Run Flutter App

```bash
flutter run -d macos
```

**Important**: App must be fully restarted (not hot reload/restart) when changing:
- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Release.entitlements`

## Architecture Details

### Process Independence via `ProcessStartMode.detached`

The daemon survives Flutter app termination because `DaemonManager.runDaemon()` uses:

```dart
Process.start(
  binaryPath,
  [logPath],
  mode: ProcessStartMode.detached,  // Key: parent death doesn't kill child
  workingDirectory: projectRoot,
);
```

### Hardcoded Path Requirements

**Critical**: `lib/services/daemon_manager.dart` contains:

```dart
static const String projectRoot = '/Users/kihyun/Documents/GitHub/test_dart_cli';
```

This is necessary because macOS sandbox causes `Directory.current` to point to the app container (`/Users/kihyun/Library/Containers/...`) instead of the project root.

**When adapting for other machines**: Update this constant to the actual project path.

### macOS Sandbox Disabled

The app requires sandbox to be disabled to execute external binaries. Both entitlement files have:

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

If you encounter `Operation not permitted` errors when running the daemon, verify these entitlement files are correctly set.

## File Structure

```
bin/daemon.dart              # CLI daemon source (writes logs every 1s)
bin_output/daemon            # Compiled binary (gitignored)
logs/daemon_log.txt          # Daemon output (gitignored)
lib/services/daemon_manager.dart  # Process management logic
lib/screens/home_screen.dart      # UI with 6 control buttons
```

## Daemon Behavior

- Accepts log file path as first argument: `./daemon /path/to/log.txt`
- Writes timestamped heartbeat every 1 second
- Handles SIGTERM/SIGINT for graceful shutdown
- Runs independently after Flutter app exits

## Process Management

The `DaemonManager` provides:
- `runDaemon()`: Launch detached process
- `checkStatus()`: Query via `ps aux | grep daemon`
- `killDaemon(pid)`: Send SIGTERM signal
- `readLogs()`: Read last N lines from log file
- `clearLogs()`: Delete log file

## Testing the Experiment

1. Build daemon binary
2. Run Flutter app
3. Click "실행" (Run) button
4. Verify heartbeats in logs
5. Click "앱 종료" (Exit App) button
6. Restart Flutter app
7. Click "상태 확인" (Check Status) - daemon should still be running
8. Check logs - heartbeats should have continued during app downtime
