# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **macOS Zip Updater Test App** - a Flutter + Dart CLI experiment demonstrating automatic app update mechanism via a detached daemon process.

**Core Goal**: Simulate macOS app auto-update flow where:
1. User clicks "Update" button in Flutter app
2. Daemon process starts in background (detached)
3. Flutter app immediately exits
4. Daemon performs update simulation (10 log entries)
5. Daemon relaunches the Flutter app

**Architecture**: Two separate processes
- **Flutter macOS App** (`lib/`): Simple UI with version display and update button
- **Dart CLI Daemon** (`bin/daemon.dart`): Independent background updater process

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
  [logPath, flutterAppPath, zipFilePath],  // 3 arguments
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
bin/daemon.dart                          # Updater daemon source
bin_output/daemon                        # Compiled daemon binary (gitignored)
app_out/test_dart_cli_updater.zip       # Downloaded update package (simulated)
logs/daemon_log.txt                      # Update process logs (gitignored)
lib/services/daemon_manager.dart         # Process management and hardcoded paths
lib/screens/home_screen.dart             # Simple UI: version display + update button
```

## Daemon Behavior

The daemon (`bin/daemon.dart`) accepts **3 arguments**:
```bash
./daemon <log_file_path> <flutter_app_path> <zip_file_path>
```

**Update Flow**:
1. Receives 3 arguments from Flutter app:
   - Log file path: `/Users/kihyun/Documents/GitHub/test_dart_cli/logs/daemon_log.txt`
   - Flutter app path: `/Users/kihyun/Documents/GitHub/test_dart_cli/build/macos/Build/Products/Debug/test_dart_cli.app`
   - Zip file path: `/Users/kihyun/Documents/GitHub/test_dart_cli/app_out/test_dart_cli_updater.zip` (hardcoded)

2. Logs startup info and received paths
3. Handles SIGTERM/SIGINT for graceful shutdown
4. Outputs 10 log entries simulating update progress (500ms intervals)
5. Launches the Flutter app using `open -a test_dart_cli`
6. Exits gracefully

## Flutter App UI

**Simple Interface**:
- **Version Info Card**: Displays hardcoded version (v1.0.0) and build number (1)
- **Update Button**: Single large button that triggers the update process
- **Update Log Card**: Shows status messages during update

**Update Process** (triggered by button click):
1. Calls `DaemonManager.runDaemon()`
2. Shows "업데이트 프로세스 시작 중..." message
3. Waits 1 second
4. App exits (`exit(0)`)
5. Daemon continues in background
6. Daemon relaunches app after 10 log entries

## Process Management

The `DaemonManager` provides:
- `runDaemon()`: Launch detached daemon with 3 arguments
- `binaryPath`: Path to compiled daemon in app bundle
- `logPath`: Project logs directory
- `flutterAppPath`: Built Flutter app path
- `zipFilePath`: Hardcoded update package path

## Testing the Update Flow

1. **Compile daemon binary**:
   ```bash
   dart compile exe bin/daemon.dart -o bin_output/daemon
   ```

2. **Copy binary to app bundle** (or use build script)

3. **Run Flutter app**:
   ```bash
   flutter run -d macos
   ```

4. **Click "업데이트 시작" button**

5. **Observe**:
   - App shows loading indicator
   - After 1 second, app closes
   - Check `logs/daemon_log.txt` - should see 10 progress entries
   - App automatically relaunches after daemon completes

6. **Verify logs**:
   ```bash
   cat logs/daemon_log.txt
   ```
