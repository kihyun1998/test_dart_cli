# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **macOS Zip Updater Test App** - a Flutter + Dart CLI experiment demonstrating automatic app update mechanism via a detached daemon process.

**Core Goal**: Simulate macOS app auto-update flow where:
1. User clicks "Update" button in Flutter app
2. Daemon process starts in background (detached)
3. Flutter app immediately exits
4. Daemon waits for parent process to exit
5. Daemon backs up current app to `.backup`
6. Daemon performs update operations (zip extraction, file replacement)
7. Daemon relaunches the Flutter app

**Architecture**: Two separate processes
- **Flutter macOS App** (`lib/`): Simple UI with version display and update button
- **Dart CLI Daemon** (`bin/daemon.dart`): Independent background updater process with backup/restore capability

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
  [parentPid, logPath, flutterAppPath, zipFilePath],  // 4 arguments
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

The daemon (`bin/daemon.dart`) accepts **4 arguments**:
```bash
./daemon <parent_pid> <log_file_path> <flutter_app_path> <zip_file_path>
```

**Update Flow**:
1. Receives 4 arguments from Flutter app:
   - Parent PID: Process ID of the Flutter app to monitor
   - Log file path: `/Users/kihyun/Documents/GitHub/test_dart_cli/logs/daemon_log.txt`
   - Flutter app path: `/Applications/test_dart_cli.app` (actual installed app location)
   - Zip file path: `/Users/kihyun/Documents/GitHub/test_dart_cli/app_out/test_dart_cli_updater.zip` (hardcoded)

2. Logs startup info and received paths
3. Monitors parent process until it exits (1 second intervals)
4. Handles SIGTERM/SIGINT for graceful shutdown
5. **Backs up current app** using rename (fast, atomic):
   - Removes existing backup if present at `~/.test_dart_cli_backup/test_dart_cli.app.backup`
   - Renames entire `.app` bundle from `/Applications` to backup location
   - Verifies backup exists
   - If backup fails: relaunches app and exits with error
6. **Extracts update package**:
   - Creates temporary directory with `Directory.systemTemp.createTemp()`
   - Extracts zip using `archive` package
   - **Restores Unix file permissions** from zip metadata (critical for executables)
   - Verifies `test_dart_cli.app` exists in extracted files
   - If extraction fails: rolls back from backup, relaunches app, exits
7. **Installs new app** using rename:
   - Renames extracted app from temp directory to `/Applications/test_dart_cli.app`
   - Verifies installation
   - If installation fails: cleans up temp, rolls back from backup, relaunches app, exits
8. **Cleanup on success**:
   - Deletes temporary extraction directory
   - Deletes backup (old app version)
9. Launches the Flutter app using `open -a test_dart_cli`
10. Exits gracefully

**Key Implementation Details**:
- Uses `rename()` instead of recursive copy for speed and atomicity
- Preserves Unix file permissions during zip extraction (fixes "can't be opened" errors)
- Comprehensive rollback mechanism on any failure
- All errors logged to `daemon_log.txt`

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
- `runDaemon()`: Launch detached daemon with 4 arguments (parent PID, log path, app path, zip path)
- `binaryPath`: Path to compiled daemon in app bundle
- `logPath`: Project logs directory
- `flutterAppPath`: Installed app path (e.g., `/Applications/test_dart_cli.app`)
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
   - Check `logs/daemon_log.txt` - should see:
     - Parent process monitoring
     - Backup creation logs (rename to `~/.test_dart_cli_backup/`)
     - Zip extraction with permission restoration
     - New app installation
     - Temp cleanup and backup deletion
     - App relaunch
   - Verify backup created at `~/.test_dart_cli_backup/test_dart_cli.app.backup` (deleted after successful update)
   - App automatically relaunches after daemon completes

6. **Verify logs**:
   ```bash
   cat logs/daemon_log.txt
   ```
